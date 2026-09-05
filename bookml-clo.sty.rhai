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

let class = if LookupDefinition("\\bml@class@name") != () { UnTeX(Expand(T_CS("\\bml@class@name"))) } else { "" };

let classes = ["extarticle", "extbook", "extletter", "extproc", "extreport", "a0poster", "aastex", "acmart", "beamer", "elsart", "IEEEtran", "iopart", "JHEP", "JHEP2", "JHEP3", "minimal", "slides", "amsart", "amsbook", "amsproc", "article", "report", "book"];

if ! classes.contains(class) {
  let class = for cls in classes {
    if LookupBool(cls + ".cls_loaded") {
      break cls;
    }
  };
  DefMacro("\\bml@class@name", class);
}

DefMacro("\\bml@ltxml@dpi", || {
  let dpi = LookupString("KV@LTXML@dpi");
  return if dpi != "" { dpi } else { "100" };
});

InputDefinitions("bookml/bookml-clo.sty", #{ noltxml: true });

AssignFloat("NOMINAL_FONT_SIZE", parse_float(ToString(Digest(T_CS("\\f@size")))), "global");

RelaxNGSchema("bookml/schema");