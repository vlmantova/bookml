/*
  BookML: bookdown flavoured GitBook port for LaTeXML
  Copyright (C) 2021-26 Vincenzo Mantova <v.l.mantova@leeds.ac.uk>

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

if LaTeXMLVersion() != "0.7.6" {
  Fatal("bookml", LaTeXMLVersion(), "BookML requires latexml-oxide v0.7.6");
}

/*** Version comparison utils
  The assumption is that the version number is of the form X or X-Y, where X, Y
  use '.' to separate the version components, and we follow the SemVer-like
  convention that -Y is a prerelease prefix, so X comes after X-Y.
***/
fn splitSemVer(ver) {
  let splitVer = ver.split("-");
  for (v, i) in splitVer {
    ver[i] = v.split(".");
  }
  return splitVer;
}

fn lexLeq(a, b) {
  let lenB = b.len;
  for (cmp, i) in a {
    if (i >= b.len || cmp > b[i]) {
      // absent component < any component
      return false;
    } else if (cmp < b[i]) {
      return true;
    }
  }
  return true;
}

fn semVerLeq(a, b) {
  let splitA = splitSemVer(a);
  let splitB = splitSemVer(b);
  return lexLeq(splitA[0], splitB[0]) && (splitA.len > splitB.len || lexLeq(splitA[1], splitB[1]));
}

fn maxVersion(ver) {
  return semVerLeq(ver, LaTeXMLVersion());
}

fn minVersion(ver) {
  return semVerLeq(LaTeXMLVersion(), ver);
}

/*** BookML resources */
DefPrimitive("\\bml@resources",
  || {
    let jobname = UnTeX(Expand(T_CS("\\jobname")));
    let style = parse_int(UnTeX(Expand(T_CS("\\bml@style"))));
    let styles = ["none", "plain", "gitbook"];

    style = styles[style];

    let output = run("perl", ["bookml/resources.pl", "--style", style, jobname], "resources", "failed to find files in bookml/CSS and bmluser");

    let stdout = output.stdout;
    stdout.replace("\r\n", "\n");

    for file in stdout.split("\n") {
      if file != "" {
        RequireResource(file);
      }
    }
  }
);

/*** Minimal HTML5 parser
  Deviations from spec:
  - only XML entities are decoded
  - ambiguous & allowed in attributes
  - final / closes all elements, including non-void, unless part of attribute
  - limited error checking
***/
fn decodeHTMLEntities(str) {
  str.replace("&lt;", "<");
  str.replace("&gt;", ">");
  str.replace("&apos;", "'");
  str.replace("&quot;", '"');

  // decode character references
  while str.contains(`&#`) {
    let parts = str.split("&#", 2);
    if parts[1].contains(";") {
      let subparts = parts[1].split(";", 2);
      let entity = `&#${subparts[0]};`;
      let char = "";

      try {
        let parsed = ParseXML(entity.to_lower());
        char = parsed[0].content();
        // keep & encoded (it will be decoded at the end)
        if char == "&" {
          char = "&amp;";
        }
      } catch {
        // invalid reference, deactivate & (it will be decoded at the end)
        char = `&amp;#${subparts[0]};`;
      };

      str.replace(entity, char);
    } else {
      // unterminated reference, encode & (it will be decoded at the end)
      str = `${parts[0]}&amp;#${parts[1]}`;
    }
  }

  str.replace("&amp;", "&");
  return str;
}

fn parseHTMLAfterElem(rawtag) {
  let parsed = #{
    selfclose: false,
    attrs: #{ }
  };

  let state = 3;
  let name = "";
  let value = "";

  // 3/4/5. after attribute/attribute name/'='
  // 6. in attribute name
  // 7/8/9. in attribute value within single/double/no quotes
  let len = rawtag.len;
  for (c, i) in rawtag.chars {
    switch [state, c] {
      // final '/'
      [3, '/'] | [4, '/'] | [6, '/'] =>  {
        if i == len - 1 {
          parsed.selfclose = true;
        } else {
          Error("malformed", rawtag, "skipping invalid character '/' in attribute list");
          if state == 6 {
            parsed.attrs[name] = "";
            name = "";
            state = 4;
          }
        }
      }
      // whitespace handling
      [3, ' '] | [3, '\n'] | [3, '\x12'] | [3, '\r'] |
      [4, ' '] | [4, '\n'] | [4, '\x12'] | [4, '\r'] |
      [5, ' '] | [5, '\n'] | [5, '\x12'] | [5, '\r'] => (),
      [6, ' '] | [6, '\n'] | [6, '\x12'] | [6, '\r'] => state = 4,
      // found 'name='
      [4, '='] | [6, '='] => { value = ""; state = 5 },
      // start of attribute value
      [5, '\''] => state = 7,
      [5, '"'] => state = 8,
      // end of attribute value
      [7, '\''] | [8, '"'] |
      [9, ' '] | [9, '\n'] | [9, '\x12'] | [9, '\r'] => {
        if name == "" {
          Error("malformed", `=${c}${value}${c}`, "skipping HTML attribute without name");
        } else {
          parsed.attrs[name] = decodeHTMLEntities(value);
          name = "";
        }
        value = "";
        state = 3;
      },
      _ => switch state {
        3 => { name += c; state = 6; },
        // attribute name followed directly by other attribute name
        4 => {
          parsed.attrs[name] = "";
          name = c;
          state = 6;
        },
        5 => { value = c; state = 9; },
        6 => name += c,
        7 | 8 | 9 => value += c
      }
    }
  }

  if name != "" {
    parsed.attrs[name] = decodeHTMLEntities(value);
  }

  return parsed;
}

/*** Inline HTML tags via environments
  \begin{h:TAG}[attr1=value,attr2] ... \end{h:TAG}
***/
DefPrimitive("\\bml@html@setinline Expanded Expanded",
  |tag, inline| AssignMapping("bml@html@inline", tag, inline));

DefPrimitive("\\bml@enter@horizontal", || (), #{
  enterHorizontal: true,
  reversion: ""
});

DefPrimitive("\\bml@leave@horizontal", || (), #{
  leaveHorizontal: true,
  reversion: ""
});

DefEnvironment("{bml@html@env@} Undigested",
  "?#inline\
    (<ltx:xmlinlineelem name='#elem' ns='http://www.w3.org/1999/xhtml'>#body</ltx:xmlinlineelem>)\
    (<ltx:xmlelem name='#elem' ns='http://www.w3.org/1999/xhtml'>#body</ltx:xmlelem>)",
  #{
    afterDigestBegin: || if whatsit().propertyString("inline") != "" {
      Digest(T_CS("\\bml@enter@horizontal"));
    } else {
      Digest(T_CS("\\bml@leave@horizontal"));
    },
    properties: |elem| #{
      elem: elem,
      inline: LookupMapping("bml@html@inline", elem)
    },
    reversion: ""
  }
);

DefConstructor("\\bml@html@attr@ Undigested Undigested",
  "?#1(<ltx:xmlattr name='#1' value='#value'/>)",
  #{
    properties: |name, value| #{
      value: decodeHTMLEntities(value)
    },
    reversion: ""
  }
);

/*** Inline HTML tags via \<
  \<TAG attr1="value" attr>
***/
DefConstructor("\\bml@html@tag Undigested",
  |document, rawtag| {
    let props = document.getProperties();
    let close = props.close == "true";
    let elem = props.elem;
    let qname = `ltx:xml${props.inline}elem`;

    if !close {
      let parsed = parseHTMLAfterElem(props.afterElem);

      document.openElement(qname);
      let el = document.getNode();

      el.setAttribute("name", elem);
      el.setAttribute("ns", "http://www.w3.org/1999/xhtml");

      for a in parsed.attrs.keys() {
        let attr = document.insertElement("ltx:xmlattr", #{ name: a });
        attr.setAttribute("value", parsed.attrs[a]);
      }

      if parsed.selfclose {
        document.closeElement(qname);
      }
    } else {
      document.closeElement(qname);
    }
  },
  #{
    afterDigest: || if whatsit().propertyString("close") != "true" {
      if whatsit().propertyString("inline") != "" {
        Digest(T_CS("\\bml@enter@horizontal"))
      } else {
        Digest(T_CS("\\bml@leave@horizontal"))
      }
    },
    properties: |rawtag| {
      let close = rawtag.starts_with("/");
      if close { rawtag.crop(1); }

      let elem = rawtag;
      for c in [' ', '\n', '\x12', '\r', '/'] {
        let i = elem.index_of(c);
        if i > -1 { elem.crop(0,i); }
      }
      rawtag.crop(elem.len);
      // TeX uses carriage return to represent newlines
      rawtag.replace("\r", "\n");

      let inline = LookupMapping("bml@html@inline", elem);

      return #{
        afterElem: rawtag,
        close: close,
        elem: elem,
        inline: inline
      }
    },
    reversion: ""
  }
);

/*** Inline HTML via \bmlRawHTML */
DefConstructor("\\bml@html@raw@ Undigested",
  |document, rawhtml| {
    let rawhtml = UnTeX(rawhtml);
    // TeX uses carriage return to represent newlines
    rawhtml.replace("\r", "\n");
    let nodes = ParseXML(`<div xmlns='http://www.w3.org/1999/xhtml'>${rawhtml}</div>`);

    if nodes.len > 0 {
      let inPreamble = document.getProperty("inPreamble") == "true";
      let qname = if inPreamble { "ltx:resource" } else { "ltx:rawhtml" };

      document.openElement(qname);

      if inPreamble {
        let el = document.getNode();
        el.setAttribute("type", "application/xhtml+xml");
      }

      document.insertXML(nodes[0].children());
      document.closeElement(qname);
    }
  },
  #{
    properties: |rawhtml| #{
      inPreamble: LookupBool("inPreamble")
    },
    reversion: ""
  }
);

/*** Image generation via LaTeX
  \begin{bmlimage} ... \end{bmlimage}
  \bmlImageEnvironment{tikzipicture}
***/
fn run(exe, args, object, summary) {
  let cmd = Command(exe);
  cmd.args(args);

  let output = cmd.output();

  if output.stderr != "" {
    NoteSTDERR(output.stderr);
  }

  if output.status != 0 {
    Error("bookml", object, summary);
  }

  return output;
}

DefPrimitive("\\bml@notelog Undigested", |line| { NoteLog(line); });

DefPrimitive("\\bml@image@generate",
  || {
    let jobname = UnTeX(Expand(T_CS("\\jobname")));
    let source = LookupString("SOURCEFILE");
    let imagescale = UnTeX(Expand(T_CS("\\bml@image@scale")));

    try {
      parse_float(imagescale);
    } catch {
      Error("malformed", "imagescale", `ignoring non-decimal value '${imagescale}' for option imagescale of bookml.sty`);
      DefMacro("\\bml@image@scale", "1");
      imagescale = "1";
    }

    ProgressSpinup("BookML images");

    let output = run("perl", ["bookml/bmlimages.pl", "--imagescale", imagescale, "--jobname", jobname, source], "bmlimages", "failed to generate bmlimages");

    for depths in output.stdout.split("\n") {
      if depths != "" {
        let dimensions = depths.split(":");
        let counter = dimensions[0];
        let depth = dimensions[3];
        AssignMapping("bml@image@depth", counter, depth);
      }
    }

    ProgressSpindown("BookML images");

    Digest(TokenizeInternal("\
      \\newread\\bml@image@logfile\
      \\openin\\bml@image@logfile bmlimages/dvi/" + jobname + "/" + jobname + ".bmllog\
      \\loop\\ifeof\\bml@image@logfile\\else\\begingroup\
      \\catcode`\\^^M=12\\catcode`\\ =12\\catcode`^=12\
      \\catcode`\\{=12\\catcode`\\}=12\
      \\read\\bml@image@logfile to \\bml@image@logline\
      \\global\\let\\bml@image@logline\\bml@image@logline\\endgroup\
      \\expandafter\\bml@notelog\\expandafter{\\bml@image@logline}\
      \\let\\bml@image@logline\\@undefined\\repeat\
      \\closein\\bml@image@logfile"));

    // do not run twice!
    Let("\\bml@image@generate", "\\relax");
  }
);

DefConstructor("\\bml@image@depth Expanded",
  |document, counter| {
    let depth = LookupMapping("bml@image@depth", ToString(counter));
    let fsize = parse_float(document.getProperty("fsize"));

    if depth != "" {
      let node = document.findnode("*[last()]", document.getNode());
      let imagescale = document.getProperty("imagescale");

      node.setAttribute("imagedepth", ((0.5 + parse_float(depth)) * parse_float(imagescale) * 72.27 / 72 / fsize).to_string() + "em");
    }
  },
  #{
    properties: |counter| #{
      fsize: UnTeX(Expand(T_CS("\\f@size"))),
      imagescale: UnTeX(Expand(T_CS("\\bml@image@scale")))
    }
  }
);

/*** Alternative text */
DefConstructor("\\bmlDescription Semiverbatim",
  |document, text| {
    let curr = document.getElement();
    let save = document.getNode();
    let elem = document.findnode("*[last()]", curr);

    document.setNode(elem);
    document.setAttribute("description", ToString(text));
    document.setNode(save);
  },
  #{
    reversion: ""
  }
);

/*** Add class to previous node */
DefConstructor("\\bmlPlusClass Semiverbatim",
  |document, class| {
    let curr = document.getElement();
    let node = document.findnode("*[last()]", curr);
    document.addClass(node, ToString(class));
  },
  #{
    reversion: ""
  }
);

/*** Disable MathJax locally */
DefConstructor("\\bmlDisableMathJax",
  |document| {
    let elem = document.getElement();
    let eqelem = document.findnode("ancestor-or-self::ltx:equation[1]//ltx:Math", elem);

    if eqelem != () {
      document.addClass(eqelem, "bml_disable_mathjax");
    }
  },
  #{
    reversion: ""
  }
);

/*** Unicode variation sequence */
DefMath("\\emptyset", "\u2205\uFE00", #{ role: "ID", meaning: "empty-set" });

/*** LaTeXML bugfixes and improvements */

/*** Rules */
let hrule = LookupDefinition("\\hrule");
let vrule = LookupDefinition("\\vrule");
let rule = LookupDefinition("\\rule");

// relative the rule sizes
for def in [vrule, hrule] {
  def.pushAfterDigest(|| {
    let fsize = parse_float(UnTeX(Expand(T_CS("\\f@size"))));
    for prop in ["rwidth", "rheight", "rdepth"] {
      let size = whatsit().propertyString(prop);
      if size.ends_with("pt") {
        size.remove("pt");
        let relsize = parse_float(size) / fsize;
        whatsit().setProperty(prop, relsize.to_string() + "em");
      }
    }
  });
}

rule.pushAfterDigest(|| {
  let fsize = parse_float(UnTeX(Expand(T_CS("\\f@size"))));
  for prop in ["width", "height", "offset"] {
    let size = whatsit().propertyString(prop);
    if size.ends_with("pt") {
      size.remove("pt");
      let relsize = parse_float(size) / fsize;
      whatsit().setProperty(prop, relsize.to_string() + "em");
    }
  }
});

// add CSS classes
hrule.pushAfterConstruct(|document| {
  let props = document.getProperties();
  if (!props["isHorizontal"]) {
    let elem = document.findnode("*[last()]", document.getElement());
    document.addClass(elem, "bml_hrule");
  }
});

vrule.pushAfterConstruct(|document| {
  let props = document.getProperties();
  if (!props["invisible"] && !props["isVertical"]) {
    let elem = document.findnode("*[last()]", document.getElement());
    document.addClass(elem, "bml_hrule");
  }
});

// \hrule switches to vertical mode: close the parent ltx:p element, unconditionally
hrule.pushBeforeConstruct(|document| {
  document.floatToElement("ltx:block");
});

// \vrule switches to horizontal mode: open an inline content (see \hbox for reference)
vrule.pushBeforeConstruct(|document| {
  // force opening an inline context
  let text = document.insertElement("ltx:text");
  document.removeNode(text);
});

AtBeginDocument("\\bml@fix@algo");

DefPrimitive("\\bml@fix@algo",
  || {
    if (LookupDefinition("\\lx@algo@rule") != ()) {
      DefConstructor("\\lx@algo@rule", "<ltx:rule class='bml_vrule bml_algo_rule' />");
    }
  },
  #{
    reversion: ""
  }
);

/*** Framed boxes */
fn addClassToCtor(def, class) {
  if def != () {
    def.pushAfterConstruct(|document| {
      let elem = document.findnode("*[last()]", document.getElement());
      document.addClass(elem, class);
    });
  }
}

let framebox = LookupDefinition("\\@framebox");
let boxedtext = LookupDefinition("\\boxed@text");
let fcolorbox = LookupDefinition("\\fcolorbox");

DefPrimitive("\\bml@fix@framedboxes",
  || {
    addClassToCtor(framebox, "bml_framebox");
    addClassToCtor(boxedtext, "bml_framebox");
    addClassToCtor(fcolorbox, "bml_framebox");
  },
  #{
    reversion: ""
  }
);

AtBeginDocument("\\bml@fix@framedboxes");

/* save type of alignment (intended for multline) */
let alignment = LookupDefinition("\\lx@begin@alignment");
alignment.pushAfterConstruct(|document| {
  let curr = document.getElement();
  let elem = document.findnode("*[last()]", curr);
  let name = elem.getAttribute("name");
  if name != "" {
    document.addClass(elem, `bml_alignment_${name}`);
  }
});

InputDefinitions("bookml/bookml.sty", #{ noltxml: true });
