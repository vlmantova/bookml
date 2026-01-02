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
    version    = "1.0"
    xmlns:xsl  = "http://www.w3.org/1999/XSL/Transform"
    xmlns:exsl = "http://exslt.org/common"
    xmlns:ltx  = "http://dlmf.nist.gov/LaTeXML"
    xmlns:f    = "http://dlmf.nist.gov/LaTeXML/functions"
    xmlns:b    = "https://vlmantova.github.io/bookml/functions"
    xmlns:m    = "http://www.w3.org/1998/Math/MathML"
    extension-element-prefixes = "exsl"
    exclude-result-prefixes    = "exsl ltx f b m">

  <!-- include the standard LaTeXML html5 stylesheet -->
  <xsl:import href="urn:x-LaTeXML:XSLT:LaTeXML-html5.xsl"/>

  <!-- include the BookML utils -->
  <xsl:import href="utils.xsl"/>

  <!-- include the BookML XHTML5 fixes -->
  <xsl:import href="xhtml5.xsl"/>

  <!-- include the GitBook style -->
  <xsl:import href="gitbook.xsl"/>

  <xsl:template match="/">
    <xsl:choose>
      <!-- final tweaks have already been applied -->
      <xsl:when test="/*[@bml-colors-done]">
        <xsl:apply-imports/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="xhtml-to-html">
          <!-- convert XHTML5 to HTML5 -->
          <xsl:with-param name="fragment">
            <!-- apply alterations -->
            <xsl:call-template name="bml-alter">
              <xsl:with-param name="fragment">
                <xsl:apply-imports/>
              </xsl:with-param>
            </xsl:call-template>
          </xsl:with-param>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="xhtml-to-html">
    <xsl:param name="fragment" />
    <xsl:apply-templates select="exsl:node-set($fragment)" mode="xhtml-to-html" />
  </xsl:template>

  <xsl:template match="@*|node()" mode="xhtml-to-html">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" mode="xhtml-to-html" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="*" mode="xhtml-to-html">
    <xsl:element name="{local-name()}">
      <xsl:apply-templates select="@*|node()" mode="xhtml-to-html" />
    </xsl:element>
  </xsl:template>

  <xsl:template match="m:annotation-xml/@encoding[.='application/xhtml+xml']" mode="xhtml-to-html">
    <xsl:attribute name="encoding">text/html</xsl:attribute>
  </xsl:template>

  <!-- modern and mobile friendly tags (backported from 0.8.6) -->
  <xsl:template match="/" mode="head-begin">
    <xsl:if test="b:max-version('0.8.5')">
      <meta charset="UTF-8"/>
      <meta name="viewport"
        content="width=device-width, initial-scale=1, shrink-to-fit=no"/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="/" mode="head-resources">
    <xsl:variable name="font-size" select="substring-before(substring-after(//processing-instruction()[local-name()='latexml'][contains(.,'bml-font-size=&quot;')],'bml-font-size=&quot;'),'&quot;')" />
    <xsl:variable name="dpi" select="substring-before(substring-after(//processing-instruction()[local-name()='latexml'][contains(.,'DPI=&quot;')],'DPI=&quot;'),'&quot;')" />
    <xsl:if test="$font-size">
      <style>:root { --bml-ltx-font-size: <xsl:value-of select="$font-size" />; }</style>
    </xsl:if>
    <xsl:if test="$dpi">
      <style>:root { --bml-ltxml-dpi: <xsl:value-of select="$dpi" />; }</style>
    </xsl:if>
    <xsl:apply-imports />
  </xsl:template>

  <!-- add BookML resources at the end of the body, including MathJax -->
  <xsl:template match="/" mode="body-end">
    <xsl:apply-templates select="//ltx:resource[contains(@type,';bmllocation=body')]" mode="bml-resource"/>
  </xsl:template>

</xsl:stylesheet>
