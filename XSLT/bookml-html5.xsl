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

  <!-- strip namespaces from XHTML5 output -->
  <xsl:template match="/">
    <xsl:call-template name="bml-alter">
      <xsl:with-param name="fragment">
        <xsl:apply-imports/>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="*" mode="bml-alter">
    <xsl:element name="{local-name()}">
      <xsl:apply-templates select="@*|node()" mode="bml-alter"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="m:annotation-xml/@encoding[.='application/xhtml+xml']" mode="bml-alter">
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

  <!-- add BookML resources at the end of the body, including MathJax -->
  <xsl:template match="/" mode="body-end">
    <xsl:apply-templates select="//ltx:resource[contains(@type,';bmllocation=body')]" mode="bml-resource"/>

    <!-- MathJax -->
    <xsl:if test="$MATHJAX3">
      <!-- polyfill for IE11 -->
      <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"/>
      <!-- mml-chtml component only (maths is already in MathML) -->
      <xsl:text>&#x0A;</xsl:text>
      <!-- do not process equations disabled with \bmlDisableMathJax (code suggested by Davide P. Cervone) -->
      <script>
        MathJax = {
          startup: {
            ready() {
              class bmlFindMathML extends MathJax._.input.mathml.FindMathML.FindMathML {
                processMath(set) {
                  const adaptor = this.adaptor;
                  for (const node of set.values()) {
                    if (adaptor.hasClass(node, 'bml_disable_mathjax')) {
                      set.delete(node);
                    }
                  }
                  return super.processMath(set);
                }
              }

              MathJax._.components.global.combineDefaults(MathJax.config, 'mml', {FindMathML: new bmlFindMathML()});

              MathJax.startup.defaultReady();
            }
          }
        };
      </script>
      <xsl:text>&#x0A;</xsl:text>
      <script id="MathJax-script" async=""
        src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/mml-chtml.js"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:if>

    <xsl:if test="$MATHJAX2">
      <script type="text/javascript" async=""
        src="https://cdn.jsdelivr.net/npm/mathjax@2?config=MML_CHTML"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:if>

  </xsl:template>

</xsl:stylesheet>
