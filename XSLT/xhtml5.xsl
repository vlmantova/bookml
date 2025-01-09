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
    xmlns:f   = "http://dlmf.nist.gov/LaTeXML/functions"
    xmlns:b   = "https://vlmantova.github.io/bookml/functions"
    xmlns:svg = "http://www.w3.org/2000/svg"
    xmlns:xlink = "http://www.w3.org/1999/xlink"
    xmlns:xhtml = "http://www.w3.org/1999/xhtml"
    xmlns:m   = "http://www.w3.org/1998/Math/MathML"
    xmlns     = "http://www.w3.org/1999/xhtml"
    exclude-result-prefixes = "ltx f b svg xlink m">

  <!-- remove the outdated Content-type meta tag (backported from 0.8.6) -->
  <xsl:template match="/" mode="head-content-type">
    <xsl:choose>
      <xsl:when test="b:max-version('0.8.5')"/>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- add BookML resources at the end of the head -->
  <xsl:template match="/" mode="head-end">
    <xsl:apply-templates select="//ltx:resource[contains(@type,';bmllocation=head')]" mode="bml-resource"/>
  </xsl:template>

  <!-- add BookML resources at the end of the body, including MathJax -->
  <xsl:template match="/" mode="body-end">
    <xsl:apply-templates select="//ltx:resource[contains(@type,';bmllocation=body')]" mode="bml-resource"/>
  </xsl:template>

  <!-- BookML external resources -->
  <xsl:template match="ltx:resource[contains(@type,';bmllocation=') and @src]" mode="bml-resource">
    <xsl:choose>
      <xsl:when test="starts-with(@type,'text/javascript;')">
        <script src="{f:url(@src)}"/>
        <xsl:text>&#x0A;</xsl:text>
      </xsl:when>
      <xsl:when test="starts-with(@type,'text/css;')">
        <link href="{f:url(@src)}" rel="stylesheet"/>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <!-- BookML inline resources -->
  <xsl:template match="ltx:resource[contains(@type,';bmllocation=') and text()]" mode="bml-resource">
    <xsl:choose>
      <xsl:when test="starts-with(@type,'text/javascript;')">
        <script>
          <xsl:text>&#x0A;</xsl:text>
          <xsl:value-of select="text()"/>
        </script>
      </xsl:when>
      <xsl:when test="starts-with(@type,'text/css;')">
        <style>
          <xsl:text>&#x0A;</xsl:text>
          <xsl:value-of select="text()"/>
        </style>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <!-- remove date from subpages, add 'hasAnchor' class for GitBook -->
  <xsl:template match="ltx:title">
    <xsl:param name="context"/>
    <xsl:if test="not(parent::*/child::ltx:titlepage)">
      <xsl:text>&#x0A;</xsl:text>
      <xsl:call-template name="bml-maketitle">
        <xsl:with-param name="context" select="$context"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:template match="ltx:TOC/ltx:title"/>

  <xsl:template name="bml-maketitle">
    <xsl:param name="context"/>
    <xsl:choose>
      <xsl:when test="b:max-version('0.8.5') and (not($GITBOOK) or //ltx:navigation/ltx:ref[@rel='start'] or f:seclev-aux(local-name(..))!='0')">
        <xsl:element name="{concat('h',f:section-head-level(parent::*))}" namespace="{$html_ns}">
          <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
          <xsl:call-template name="add_id"/>
          <xsl:call-template name="add_attributes"/>
          <!-- avoid class styling when $GITBOOK -->
          <xsl:if test="$GITBOOK"><xsl:attribute name="class"/></xsl:if>
          <xsl:apply-templates select="." mode="begin">
            <xsl:with-param name="context" select="$innercontext"/>
          </xsl:apply-templates>
          <xsl:apply-templates>
            <xsl:with-param name="context" select="$innercontext"/>
          </xsl:apply-templates>
        </xsl:element>
        <!-- include parent's subtitle, author & date (if any)-->
        <xsl:apply-templates select="../ltx:subtitle" mode="intitle">
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
        <xsl:if test="not(parent::ltx:sidebar)">
          <xsl:call-template name="authors">
            <xsl:with-param name="context" select="$context"/>
          </xsl:call-template>
          <!-- date on front page only (backported from v0.8.6) -->
          <xsl:if test="not(//ltx:navigation/ltx:ref[@rel='start'])">
            <xsl:call-template name="dates">
              <xsl:with-param name="context" select="$context"/>
              <xsl:with-param name="dates" select="../ltx:date"/>
            </xsl:call-template>
          </xsl:if>
        </xsl:if>
        <xsl:apply-templates select="." mode="end">
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
        <xsl:text>&#x0A;</xsl:text>
        <xsl:apply-templates select="parent::*" mode="auto-toc">
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:when test="$GITBOOK and not(//ltx:navigation/ltx:ref[@rel='up']) and f:seclev-aux(local-name(..))='0'">
        <div class="header">
          <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
          <xsl:apply-templates select="." mode="begin">
            <xsl:with-param name="context" select="$innercontext"/>
          </xsl:apply-templates>
          <h1 class="title">
            <xsl:apply-templates>
              <xsl:with-param name="context" select="$innercontext"/>
            </xsl:apply-templates>
          </h1>
          <xsl:if test="../ltx:creator[@role='author']">
            <xsl:text>&#x0A;</xsl:text>
            <p class="author">
              <em>
                <xsl:apply-templates select="../ltx:creator[@role='author']" mode="intitle">
                  <xsl:with-param name="context" select="$context"/>
                </xsl:apply-templates>
              </em>
            </p>
          </xsl:if>
          <xsl:if test="../ltx:date and string(../ltx:date)">
            <p class="date">
              <em>
                <xsl:apply-templates select="../ltx:date" mode="intitle">
                  <xsl:with-param name="context" select="$context"/>
                </xsl:apply-templates>
              </em>
            </p>
          </xsl:if>
          <xsl:apply-templates select="." mode="end">
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
        </div>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- improve ltx:rawliteral so that it can output valid HTML -->
  <xsl:template match="ltx:rawliteral">
    <xsl:text disable-output-escaping="yes">&lt;</xsl:text>
    <xsl:value-of select="@open" disable-output-escaping="yes"/>
    <xsl:if test="text()">
      <xsl:text> </xsl:text>
      <xsl:value-of select="text()" disable-output-escaping="yes"/>
    </xsl:if>
    <xsl:if test="@close">
      <xsl:text> </xsl:text>
      <xsl:value-of select="@close" disable-output-escaping="yes"/>
    </xsl:if>
    <xsl:text disable-output-escaping="yes">&gt;</xsl:text>
  </xsl:template>

  <!-- add descriptive tooltip to download button -->
  <xsl:template match="ltx:listing[@data]" mode="begin">
    <xsl:param name="context"/>
    <xsl:element name="{f:blockelement($context,'div')}">
      <xsl:attribute name="class">ltx_listing_data</xsl:attribute>
      <a download="{@dataname}" title="download code">
        <xsl:call-template name="add_data_attribute">
          <xsl:with-param name="name" select="'href'"/>
        </xsl:call-template>
        <xsl:text>&#x2B07;</xsl:text>
      </a>
    </xsl:element>
  </xsl:template>

  <!-- remove unwanted spaces between tag and content in lists -->
  <xsl:template match="ltx:item">
    <xsl:param name="context"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:choose>
      <xsl:when test="$SIMPLIFY_HTML">
        <xsl:element name="{f:blockelement($context,'li')}" namespace="{$html_ns}">
          <xsl:call-template name="add_id"/>
          <xsl:call-template name="add_attributes"/>
          <xsl:apply-templates select="." mode="begin">
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
          <xsl:apply-templates select="*[local-name() != 'tags']">
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
          <xsl:apply-templates select="." mode="end">
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
        </xsl:element>
      </xsl:when>
      <xsl:when test="child::ltx:tags">
        <xsl:element name="{f:blockelement($context,'li')}" namespace="{$html_ns}">
          <xsl:call-template name="add_id"/>
          <xsl:call-template name="add_attributes">
            <xsl:with-param name="extra_style">
              <xsl:value-of select="'list-style-type:none;'"/>
              <xsl:if test="@itemsep">
                <xsl:value-of select="concat('padding-top:',@itemsep,';')"/>
              </xsl:if>
            </xsl:with-param>
          </xsl:call-template>
          <xsl:apply-templates select="." mode="begin">
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
          <xsl:apply-templates select="ltx:tags/ltx:tag[not(@role)]">
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
          <xsl:apply-templates select="*[local-name() != 'tags']">
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
          <xsl:apply-templates select="." mode="end">
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:element name="{f:blockelement($context,'li')}" namespace="{$html_ns}">
          <xsl:call-template name="add_id"/>
          <!-- if there's no ltx:tags, it's presumably intentional -->
          <xsl:call-template name="add_attributes">
            <xsl:with-param name="extra_style">
              <xsl:value-of select="'list-style-type:none;'"/>
              <xsl:if test="@itemsep">
                <xsl:value-of select="concat('padding-top:',@itemsep,';')"/>
              </xsl:if>
            </xsl:with-param>
          </xsl:call-template>
          <xsl:apply-templates select="." mode="begin">
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
          <xsl:apply-templates>
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
          <xsl:apply-templates select="." mode="end">
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:enumerate/ltx:item[ltx:tags]/ltx:para[1]/ltx:p[1] | ltx:itemize/ltx:item[ltx:tags]/ltx:para[1]/ltx:p[1]">
    <xsl:param name="context"/>
    <xsl:text>&#x200B;</xsl:text> <!-- zero width space to prevent newlines -->
    <xsl:element name="{f:blockelement($context,'p')}" namespace="{$html_ns}">
      <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$innercontext"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:enumerate/ltx:item/ltx:para[1] | ltx:itemize/ltx:item/ltx:para[1]">
    <xsl:param name="context"/>
    <xsl:element name="{f:blockelement($context,'div')}" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>

  <!-- use the <img> tag for SVG images with no scripts -->
  <xsl:template match="ltx:graphics[f:ends-with(@imagesrc,'.svg')='true' and not(
    document(@imagesrc)//svg:script or
    document(@imagesrc)//@*[starts-with(local-name(),'on')] or
    document(@imagesrc)//@href[starts-with(normalize-space(),'javascript:')] or
    document(@imagesrc)//@xlink:href[starts-with(normalize-space(),'javascript:')]
  )]">
    <xsl:param name="context"/>
    <xsl:variable name="description">
      <xsl:choose>
        <xsl:when test="@description">
          <xsl:value-of select="@description"/>
        </xsl:when>
        <xsl:when test="ancestor::ltx:figure/ltx:caption">
          <xsl:value-of select="ancestor::ltx:figure/ltx:caption/text()"/>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>
    <img src="{f:url(@imagesrc)}" alt="{$description}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
        <xsl:with-param name="extra_style">
          <xsl:if test="@imagedepth">
            <xsl:value-of select="concat('vertical-align:-',@imagedepth,'px')"/>
          </xsl:if>
        </xsl:with-param>
      </xsl:call-template>
      <xsl:if test="@imagewidth">
        <xsl:attribute name='width'>
          <xsl:value-of select="@imagewidth"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:if test="@imageheight">
        <xsl:attribute name='height'>
          <xsl:value-of select="@imageheight"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context"/>
      </xsl:apply-templates>
    </img>
  </xsl:template>

  <!-- do not use tables for simple equations -->
  <xsl:template match="ltx:equation[f:countcolumns() &lt;= 1]">
    <xsl:param name="context"/>
    <xsl:choose>
      <xsl:when test="$GITBOOK or $PLAIN">
        <xsl:apply-templates select="." mode="unaligned">
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-imports/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ugly fix for backslashes in URLs on Windows -->
  <xsl:template match="@href | @src" mode="bml-alter">
    <xsl:choose>
      <xsl:when test="b:max-version('0.8.6')">
        <xsl:attribute name="{local-name()}">
          <xsl:value-of select="b:fix-windows-paths(.)"/>
        </xsl:attribute>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- remove parentheses around dates -->
  <xsl:template name="dates">
    <xsl:param name="context"/>
    <xsl:param name="dates" select="ltx:date"/>
    <xsl:if test="$dates and normalize-space(string($dates))">
      <xsl:text>&#x0A;</xsl:text>
      <xsl:element name="div" namespace="{$html_ns}">
        <xsl:attribute name="class">ltx_dates</xsl:attribute>
        <xsl:apply-templates select="." mode="begin">
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
        <xsl:if test="not($GITBOOK or $PLAIN)"><xsl:text>(</xsl:text></xsl:if>
        <xsl:apply-templates select="$dates" mode="intitle">
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
        <xsl:if test="not($GITBOOK or $PLAIN)"><xsl:text>)</xsl:text></xsl:if>
        <xsl:apply-templates select="." mode="end">
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <!-- add default \FrameSep (=3\fboxsep=9pt) padding, if missing -->
  <xsl:template match="*[b:max-version('0.8.7') and b:has-class('ltx_framed_rectangle') and not(contains(./@style,'padding'))]/@style"
    mode="bml-alter">
    <xsl:attribute name="style">
      <xsl:text>padding:9pt;</xsl:text>
      <xsl:value-of select="." />
    </xsl:attribute>
  </xsl:template>

  <!-- HACK detect titled-frame and add negative margins to the title (TODO: compute the correct margins based on the parent padding) -->
  <xsl:template
    match="*[b:max-version('0.8.7') and b:has-class('ltx_framed_rectangle') and not(contains(./@style,'padding'))]/span[position()=1 and contains(./@style,'width:100%;')]/@style"
    mode="bml-alter">
    <xsl:attribute name="style">
      <xsl:text>margin-left:-9pt;margin-right:-9pt;margin-top:-9pt;margin-bottom:9pt;padding-left:9pt;padding-right:9pt;</xsl:text>
      <xsl:value-of select="substring-before(.,'width:100%;')" />
      <xsl:value-of select="substring-after(.,'width:100%;')" />
    </xsl:attribute>
  </xsl:template>

  <!-- MathJax workaround for non-text content in <mtext> -->
  <xsl:template match="m:math[not(b:in-list(@class,'bml_disable_mathjax',' '))]//m:mtext[*]">
    <xsl:choose>
      <xsl:when test="$MATHJAX3 or $MATHJAX2">
        <m:semantics>
          <xsl:for-each select="@*">
            <xsl:apply-templates select="." mode="copy-attribute"/>
          </xsl:for-each>
          <m:annotation-xml encoding="application/xhtml+xml" style="display: block;">
            <xsl:apply-templates/>
          </m:annotation-xml>
        </m:semantics>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- modify listings to use <pre>, <code> tags -->
  <xsl:template match="ltx:text[b:has-class('ltx_lstlisting')]">
    <xsl:param name="context" />
    <code>
      <xsl:variable name="innercontext" select="'inline'" /><!-- override -->
      <xsl:call-template name="add_id" />
      <xsl:call-template name="add_attributes" />
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$innercontext" />
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$innercontext" />
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$innercontext" />
      </xsl:apply-templates>
    </code>
  </xsl:template>

  <xsl:template match="ltx:listing">
    <xsl:param name="context" />
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="{f:blockelement($context,'div')}" namespace="{$html_ns}">
      <xsl:call-template name="add_id" />
      <xsl:call-template name="add_attributes" />
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context" />
      </xsl:apply-templates>
      <xsl:element name="{f:blockelement($context,'pre')}" namespace="{$html_ns}">
        <xsl:apply-templates>
          <xsl:with-param name="context" select="$context" />
        </xsl:apply-templates>
      </xsl:element>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context" />
      </xsl:apply-templates>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:listingline">
    <xsl:param name="context" />
    <xsl:text>&#x0A;</xsl:text>
    <code>
      <xsl:call-template name="add_id" />
      <xsl:call-template name="add_attributes" />
      <xsl:apply-templates select="." mode="begin">
        <xsl:with-param name="context" select="$context" />
      </xsl:apply-templates>
      <xsl:apply-templates>
        <xsl:with-param name="context" select="$context" />
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="end">
        <xsl:with-param name="context" select="$context" />
      </xsl:apply-templates>
      <xsl:text>&#x0A;</xsl:text>
    </code>
  </xsl:template>

  <!-- replace code space with actual space, to facilitate copy & paste -->
  <xsl:template match="ltx:text[b:max-version('0.8.7') and b:has-class('ltx_lst_space')]/text()[.='&#xA0;']">
    <xsl:text> </xsl:text>
  </xsl:template>

  <!-- recreate missing viewBox attribute -->
  <xsl:template match="ltx:picture[svg:svg[not(@viewBox) and @width and @height and svg:g/@transform]]" mode="as-svg">
    <svg:svg>
      <!-- copy id, class from parent ltx:picture, but do NOT derive css style from size -->
      <xsl:call-template name="add_id" />
      <xsl:call-template name="add_classes" />
      <xsl:call-template name="copy_foreign_attributes" />
      <xsl:apply-templates select="." mode="add_RDFa" />
      <!-- but copy other svg:svg attributes -->
      <xsl:for-each select="svg:svg/@*">
        <xsl:apply-templates select="." mode="copy-attribute" />
      </xsl:for-each>
      <xsl:variable name="width" select="svg:svg/@width" />
      <xsl:variable name="height" select="svg:svg/@height" />
      <xsl:choose>
        <!-- SVGs created by pgfsys-latexml.def.ltxml (always "0 0 $width $height" in v0.8.7, v0.8.8) -->
        <xsl:when test="starts-with(svg:svg/svg:g/@transform,'translate(')">
          <xsl:variable name="translate" select="substring-before(substring-after(svg:svg/svg:g/@transform,'translate('),')')" />
          <xsl:variable name="minx" select="-number(substring-before($translate,','))" />
          <xsl:variable name="miny" select="number(substring-after($translate,','))-$height" />
          <xsl:attribute name="viewBox"><xsl:value-of select="concat($minx,' ',$miny,' ',$width,' ',$height)" /></xsl:attribute>
        </xsl:when>
        <!-- SVGs created by xy.tex.ltxml -->
        <xsl:when test="starts-with(svg:svg/svg:g/@transform,'matrix(1 0 0 -1 ') and not(svg:svg/@style)">
          <xsl:variable name="matrix" select="substring-before(substring-after(svg:svg/svg:g/@transform,'matrix(1 0 0 -1 '),')')" />
          <xsl:variable name="minx" select="number(substring-before($matrix,' '))" />
          <!-- here $miny is used for vertical alignment -->
          <xsl:variable name="miny" select="number(substring-after($matrix,' '))-$height" />
          <xsl:attribute name="viewBox"><xsl:value-of select="concat($minx,' 0 ',$width,' ',$height)" /></xsl:attribute>
          <xsl:attribute name="style">vertical-align: <xsl:value-of select="$miny" />px;</xsl:attribute>
        </xsl:when>
      </xsl:choose>
      <xsl:if test="@description">
        <xsl:if test="@fragid">
          <xsl:attribute name="aria-labelledby"><xsl:value-of select="@fragid"/>-title</xsl:attribute>
        </xsl:if>
        <svg:title>
          <xsl:if test="@fragid">
            <xsl:attribute name="id"><xsl:value-of select="@fragid"/>-title</xsl:attribute>
          </xsl:if>
          <xsl:value-of select="@description" />
        </svg:title>
      </xsl:if>
      <xsl:apply-templates select="svg:svg/*"/>
    </svg:svg>
  </xsl:template>

</xsl:stylesheet>
