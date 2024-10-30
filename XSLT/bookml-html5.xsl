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

    <!-- MathJax -->
    <xsl:if test="$MATHJAX3">
      <xsl:text>&#x0A;</xsl:text>
      <script>
        MathJax = {
          startup: {
            ready() {
              // do not process equations disabled with \bmlDisableMathJax (code suggested by Davide P. Cervone)
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

              // preproces MathML to make MathJax aware of certain LaTeXML and BookML additional info
              const mmlFilters = MathJax.startup.input[0].mmlFilters;

              // convert the LaTeXML calligraphic (chancery) annotation to a form MathJax understands
              // since the corresponding Unicode characters render as script (rounded)
              const script2latin = {
                '𝒜': 'A', 'ℬ': 'B', '𝒞': 'C', '𝒟': 'D', 'ℰ': 'E', 'ℱ': 'F', '𝒢': 'G',
                'ℋ': 'H', 'ℐ': 'I', '𝒥': 'J', '𝒦': 'K', 'ℒ': 'L', 'ℳ': 'M', '𝒩': 'N',
                '𝒪': 'O', '𝒫': 'P', '𝒬': 'Q', 'ℛ': 'R', '𝒮': 'S', '𝒯': 'T', '𝒰': 'U',
                '𝒱': 'V', '𝒲': 'W', '𝒳': 'X', '𝒴': 'Y', '𝒵': 'Z',
              };

              mmlFilters.add((args) => {
                for (const n of args.data.getElementsByClassName('ltx_font_mathcaligraphic')) {
                  n.classList.add('MJX-tex-calligraphic');
                  const letter = script2latin[n.textContent];
                  if (letter !== undefined) { n.textContent = letter; }
                }
              });

              // adjust characters based on Unicode variation sequences
              const replacements = {
                // MathJax renders the empty set as the U+FE00 variant, so the plain character needs adjusting
                '∅': { variant: 'variant' },
                // MathJax renders script characters in rounded style, which is fine for no variation and U+FE00
                '𝒜\xFE00': { text: 'A', variant: 'tex-calligraphic' },
                'ℬ\xFE00': { text: 'B', variant: 'tex-calligraphic' },
                '𝒞\xFE00': { text: 'C', variant: 'tex-calligraphic' },
                '𝒟\xFE00': { text: 'D', variant: 'tex-calligraphic' },
                'ℰ\xFE00': { text: 'E', variant: 'tex-calligraphic' },
                'ℱ\xFE00': { text: 'F', variant: 'tex-calligraphic' },
                '𝒢\xFE00': { text: 'G', variant: 'tex-calligraphic' },
                'ℋ\xFE00': { text: 'H', variant: 'tex-calligraphic' },
                'ℐ\xFE00': { text: 'I', variant: 'tex-calligraphic' },
                '𝒥\xFE00': { text: 'J', variant: 'tex-calligraphic' },
                '𝒦\xFE00': { text: 'K', variant: 'tex-calligraphic' },
                'ℒ\xFE00': { text: 'L', variant: 'tex-calligraphic' },
                'ℳ\xFE00': { text: 'M', variant: 'tex-calligraphic' },
                '𝒩\xFE00': { text: 'N', variant: 'tex-calligraphic' },
                '𝒪\xFE00': { text: 'O', variant: 'tex-calligraphic' },
                '𝒫\xFE00': { text: 'P', variant: 'tex-calligraphic' },
                '𝒬\xFE00': { text: 'Q', variant: 'tex-calligraphic' },
                'ℛ\xFE00': { text: 'R', variant: 'tex-calligraphic' },
                '𝒮\xFE00': { text: 'S', variant: 'tex-calligraphic' },
                '𝒯\xFE00': { text: 'T', variant: 'tex-calligraphic' },
                '𝒰\xFE00': { text: 'U', variant: 'tex-calligraphic' },
                '𝒱\xFE00': { text: 'V', variant: 'tex-calligraphic' },
                '𝒲\xFE00': { text: 'W', variant: 'tex-calligraphic' },
                '𝒳\xFE00': { text: 'X', variant: 'tex-calligraphic' },
                '𝒴\xFE00': { text: 'Y', variant: 'tex-calligraphic' },
                '𝒵\xFE00': { text: 'Z', variant: 'tex-calligraphic' }
              };

              mmlFilters.add((args) => {
                let nodes = document.evaluate('.//m:mi | .//m:mn | .//m:mo | .//m:ms', args.data,
                  () => 'http://www.w3.org/1998/Math/MathML', XPathResult.UNORDERED_NODE_SNAPSHOT_TYPE);
                for (let i = 0; i &lt; nodes.snapshotLength; i++) {
                  const n = nodes.snapshotItem(i);
                  const repl = replacements[n.innerHTML];
                  if (repl !== undefined) {
                    const variant = repl['variant'];
                    const text = repl['text'];
                    if (variant !== undefined) { n.classList.add('MJX-' + variant); n.removeAttribute('mathvariant'); }
                    if (text !== undefined) { n.innerHTML = text; }
                  }
                }
              });
            }
          }
        };
      </script>
      <xsl:text>&#x0A;</xsl:text>
      <!-- mml-chtml component only (maths is already in MathML) -->
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
