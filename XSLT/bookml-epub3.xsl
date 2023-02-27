<?xml version="1.0" encoding="utf-8"?>
<!--

  BookML: bookdown flavoured GitBook port for LaTeXML
  Copyright (C) 2021-23 Vincenzo Mantova <v.l.mantova@leeds.ac.uk>

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

-->
<xsl:stylesheet
    version   = "1.0"
    xmlns:xsl = "http://www.w3.org/1999/XSL/Transform"
    xmlns:ltx = "http://dlmf.nist.gov/LaTeXML"
    exclude-result-prefixes = "ltx">

  <!-- include the standard LaTeXML html5 stylesheet -->
  <xsl:import href="urn:x-LaTeXML:XSLT:LaTeXML-epub3.xsl"/>

  <!-- include the BookML utils -->
  <xsl:import href="utils.xsl"/>

  <!-- include the BookML (X)HTML5 fixes -->
  <xsl:import href="xhtml5.xsl"/>

  <!-- EPUB3 output does not include MathJax -->
  <xsl:variable name="MATHJAX2" select="false()"/>
  <xsl:variable name="MATHJAX3" select="false()" />

  <!-- add BookML resources at the end of the body, excluding MathJax -->
  <xsl:template match="/" mode="body-end">
    <xsl:apply-templates select="//ltx:resource[contains(@type,';bmllocation=body')]" mode="bml-resource"/>
  </xsl:template>

  <!-- data URLs are not allowed in EPUB -->
  <xsl:template match="ltx:listing[@data]" mode="begin"/>

  <!-- EPUB readers have their own navigation -->
  <xsl:template match="/" mode="header"/>
  <xsl:template match="/" mode="footer"/>

  <!-- remove remote resources -->
  <xsl:template match="/">
    <xsl:call-template name="bml-alter">
      <xsl:with-param name="fragment">
        <xsl:apply-imports/>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="*[starts-with(@src,'http://') or
      starts-with(@src,'https://') or
      starts-with(@data,'http://') or
      starts-with(@data,'https://')]" mode="bml-alter"/>

</xsl:stylesheet>
