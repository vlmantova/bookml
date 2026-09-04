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

RequirePackage("latexml", ["nocomments", "noguesstabularheaders"]);

AppendSearchPath(`bookml/bindings/v${LaTeXMLVersion()}-oxide`);

DefPrimitive("\\bml@at@afterdigest Token Undigested", |cs, body| {
  let defn = LookupDefinition(cs);
  defn.pushAfterDigest(|| {
    let params = "";
    let args = "";
    for i in 1..=9 {
      args += "{" + whatsit().argString(i) + "}";
      params += "{}";
    };
    DefMacro("\\bml@after@digest@tmp" + params, body);
    Digest(TokenizeInternal("\\bml@after@digest@tmp" + args));
  });
});

LookupDefinition("\\selectfont").pushAfterDigest(|| {
  let size = ToString(Digest(T_CS("\\f@size")));
  MergeFont(#{ size: parse_float(size) });
  Digest(T_CS("\\size@update"));
});

DefMacro("\\LaTeXMLgenerator", "latexml-oxide");
AtBeginDocument("\\lx@save@parameter{bml-generator}{\\LaTeXMLgenerator}");
AtBeginDocument("\\lx@save@parameter{bml-generator-version}{\\LaTeXMLversion}");

DefPrimitive("\\bml@init@schema", || RelaxNGSchema("bookml/schema"));

DefMacro("\\bml@generator@engine", "oxide");

InputDefinitions("bookml/bookml-init.sty", #{ noltxml: true });