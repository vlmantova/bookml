<?xml version="1.0" encoding="utf-8"?>
<!--

  BookML: bookdown flavoured GitBook port for LaTeXML
  Copyright (C) 2021  Vincenzo Mantova <v.l.mantova@leeds.ac.uk>

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
    xmlns     = "http://www.w3.org/1999/xhtml"
    exclude-result-prefixes = "ltx f b">

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
  <xsl:template name="maketitle">
    <xsl:param name="context"/>
    <xsl:choose>
      <xsl:when test="b:max-version('0.8.5') and (not($GITBOOK) or //ltx:navigation/ltx:ref[@rel='up'] or f:seclev-aux(local-name(..))!='0')">
        <xsl:element name="{concat('h',f:section-head-level(parent::*))}">
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
          <xsl:if test="not(//ltx:navigation/ltx:ref[@rel='up'])">
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
    <div class="ltx_listing_data">
      <a download="" title="download code">
        <xsl:call-template name="add_data_attribute">
          <xsl:with-param name="name" select="'href'"/>
        </xsl:call-template>
        <xsl:text>&#x2B07;</xsl:text>
      </a>
    </div>
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

  <xsl:template match="ltx:enumerate/ltx:item/ltx:para[1]/ltx:p[1] | ltx:itemize/ltx:item/ltx:para[1]/ltx:p[1]">
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

</xsl:stylesheet>
