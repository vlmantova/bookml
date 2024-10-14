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
    xmlns:svg = "http://www.w3.org/2000/svg"
    xmlns:f   = "http://dlmf.nist.gov/LaTeXML/functions"
    xmlns:func = "http://exslt.org/functions"
    xmlns:b    = "https://vlmantova.github.io/bookml/functions"
    xmlns:exsl = "http://exslt.org/common"
    extension-element-prefixes = "func"
    exclude-result-prefixes = "ltx f func b exsl">

  <xsl:param name="BMLSEARCH" select="'no'"/>

  <!-- gitbook *requires* navigationtoc=context -->
  <xsl:template match="/">
    <xsl:if test="$GITBOOK and not(//ltx:navigation/ltx:TOC[@format='context'])">
      <xsl:message terminate="yes">bookml: you must call latexmlpost/latexmlc with --navigationtoc=context or disable the gitbook style via \usepackage[style=plain]{bookml}</xsl:message>
    </xsl:if>
    <xsl:choose>
      <xsl:when test="not($GITBOOK) or */@bml-colors-done">
        <xsl:apply-imports/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="fragment">
          <xsl:apply-templates mode="bml-colors"/>
        </xsl:variable>
        <xsl:apply-templates select="exsl:node-set($fragment)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- remove colour attributes to avoid interference with the bml_*color* classes -->
  <xsl:template match="@*|node()" mode="bml-colors">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" mode="bml-colors"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="/*" mode="bml-colors">
    <xsl:copy>
      <xsl:attribute name="bml-colors-done"/>
      <xsl:apply-templates select="@*|node()" mode="bml-colors"/>
    </xsl:copy>
  </xsl:template>

  <!-- remove redundant attributes that can interfere with MathJax -->
  <xsl:template match="@color | @mathcolor | @backgroundcolor | @mathbackground | @framecolor" mode="bml-colors" />

  <!-- inject @color, @mathcolor into @class (may generate duplicate classes, but we do not care) -->
  <xsl:template match="@class" mode="bml-colors" />
  <xsl:template match="/*//*[@class | @color | @mathcolor]" mode="bml-colors">
    <xsl:variable name="class">
      <xsl:value-of select="@class" />
      <xsl:for-each select="@color | @mathcolor">
        bml_color_<xsl:value-of select="substring-after(.,'#')" />
      </xsl:for-each>
    </xsl:variable>
    <xsl:copy>
      <xsl:attribute name="class"><xsl:value-of select="normalize-space($class)" /></xsl:attribute>
      <xsl:apply-templates select="@*|node()" mode="bml-colors"/>
    </xsl:copy>
  </xsl:template>

  <!-- additional javascript -->
  <xsl:template match="/" mode="head-javascript">
    <xsl:if test="$GITBOOK">
      <script src="https://code.jquery.com/jquery-3.6.0.min.js" integrity="sha256-/xUj+3OJU5yExlq6GSYGSHk7tPXikynS7ogEvDej/m4=" crossorigin="anonymous"></script>
      <script src="https://cdn.jsdelivr.net/npm/fuse.js@6.4.6"></script>
    </xsl:if>
    <xsl:apply-imports/>
  </xsl:template>

  <!-- body wrappers and scripts -->
  <xsl:template match="/" mode="body">
    <xsl:choose>
      <xsl:when test="$GITBOOK">
        <xsl:variable name="nonavtoc">
          <xsl:if test="not(//ltx:navigation/ltx:TOC/*)">
            <xsl:text> bml-no-navtoc</xsl:text>
          </xsl:if>
        </xsl:variable>
        <xsl:text>&#x0A;</xsl:text>
        <body>
          <xsl:apply-templates select="." mode="body-begin"/>
          <xsl:text>&#x0A;</xsl:text>
          <div class="book without-animation with-summary font-size-2 font-family-1{$nonavtoc}" data-basepath=".">
            <xsl:text>&#x0A;</xsl:text>
            <a href="#bml-main-content" tabindex="0" class="bml-skip-to-content">Skip to content.</a>
            <xsl:text>&#x0A;</xsl:text>
            <div class="book-summary">
              <xsl:apply-templates select="." mode="navbar"/>
            </div>
            <xsl:apply-templates select="." mode="body-main"/>
          </div>
          <xsl:text>&#x0A;</xsl:text>
          <xsl:apply-templates select="." mode="body-end"/>
          <script type="text/javascript">
            <xsl:text>
                gitbook.require(["gitbook"], function(gitbook) {
                gitbook.start({
                  "fontsettings": {
                    "theme": "white",
                    "family": "sans",
                    "size": 2
                  },
                  "download": </xsl:text>
            <xsl:choose>
              <xsl:when test="//ltx:resource[contains(@type,';bmllocation=download;bmlname=')]">
                <xsl:text>[ </xsl:text>
                <xsl:for-each select="//ltx:resource[contains(@type,';bmllocation=download;bmlname=')]">
                  <xsl:value-of select="concat('[ &quot;',f:url(@src),'&quot;, &quot;',substring-after(@type,';bmlname='),'&quot; ], ')" />
                </xsl:for-each>
                <xsl:text>]</xsl:text>
              </xsl:when>
              <xsl:otherwise>null</xsl:otherwise>
            </xsl:choose>
            <xsl:text>,
                  "search": </xsl:text>
            <xsl:choose>
              <xsl:when test="$BMLSEARCH='yes'"><xsl:text>{
                    "engine": "fuse"
                  }</xsl:text>
              </xsl:when>
              <xsl:otherwise>false</xsl:otherwise>
            </xsl:choose>
            <xsl:text>,
                  "toc": {
                    "collapse": "none"
                  }
                });
              });
            </xsl:text>
          </script>
          <xsl:text>&#x0A;</xsl:text>
        </body>
        <xsl:text>&#x0A;</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-imports/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- more wrappers and prev/next links -->
  <xsl:template match="/" mode="body-main">
    <xsl:choose>
      <xsl:when test="$GITBOOK">
        <xsl:text>&#x0A;</xsl:text>
        <div class="ltx_page_main book-body fixed">
          <xsl:text>&#x0A;</xsl:text>
          <div class="body-inner">
            <xsl:apply-templates select="." mode="body-main-begin"/>
            <xsl:apply-templates select="." mode="header"/>
            <xsl:apply-templates select="." mode="body-content"/>
            <xsl:apply-templates select="." mode="footer"/>
            <xsl:apply-templates select="." mode="body-main-end"/>
          </div>
          <xsl:text>&#x0A;</xsl:text>
          <xsl:if test="//ltx:navigation/ltx:ref[@rel='prev']">
            <a href="{f:url(//ltx:navigation/ltx:ref[@rel='prev']/@href)}" class="navigation navigation-prev" aria-label="Previous page"><i class="fa fa-angle-left"/></a>
          </xsl:if>
          <xsl:if test="//ltx:navigation/ltx:ref[@rel='next']">
            <a href="{f:url(//ltx:navigation/ltx:ref[@rel='next']/@href)}" class="navigation navigation-next" aria-label="Next page"><i class="fa fa-angle-right"/></a>
          </xsl:if>
          <xsl:if test="//ltx:navigation/ltx:ref[@rel='prev' or @rel='next']">
            <xsl:text>&#x0A;</xsl:text>
          </xsl:if>
        </div>
        <xsl:text>&#x0A;</xsl:text>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- final wrappers -->
  <xsl:template match="/" mode="body-content">
    <xsl:choose>
      <xsl:when test="$GITBOOK">
        <xsl:text>&#x0A;</xsl:text>
        <div class="page-wrapper" tabindex="-1" role="main">
          <xsl:text>&#x0A;</xsl:text>
          <div class="ltx_page_content page-inner" id="bml-main-content">
            <xsl:apply-templates select="." mode="body-content-begin"/>
            <xsl:apply-templates/>
            <xsl:apply-templates select="." mode="body-content-end"/>
            <xsl:text>&#x0A;</xsl:text>
          </div>
          <xsl:text>&#x0A;</xsl:text>
        </div>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="/ltx:*" mode="end">
    <xsl:choose>
      <xsl:when test="$GITBOOK">
        <xsl:if test="//ltx:navigation/ltx:inline-para[@class='ltx_page_footer'] | //ltx:navigation/ltx:inline-logical-block[@class='ltx_page_footer']">
          <xsl:text>&#x0A;</xsl:text>
          <footer class="bml_footer">
            <xsl:apply-templates select="//ltx:navigation/ltx:inline-para[@class='ltx_page_footer']/* | //ltx:navigation/ltx:inline-logical-block[@class='ltx_page_footer']/*"/>
          </footer>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- add 'levelN' class where N is the sectioning level -->
  <xsl:template match="ltx:document | ltx:part | ltx:chapter | ltx:section | ltx:subsection | ltx:subsubsection | ltx:paragraph | ltx:subparagraph | ltx:bibliography | ltx:appendix | ltx:index | ltx:glossary | ltx:slide">
    <xsl:param name="context"/>
    <xsl:choose>
      <xsl:when test="$GITBOOK">
        <xsl:text>&#x0A;</xsl:text>
        <section>
          <xsl:call-template name="add_id"/>
          <xsl:call-template name="add_attributes">
            <xsl:with-param name="extra_classes">normal</xsl:with-param>
          </xsl:call-template>
          <xsl:text>&#x0A;</xsl:text>
          <div class="section level{f:seclev-aux(local-name())}">
            <xsl:apply-templates select="." mode="begin">
              <xsl:with-param name="context" select="$context"/>
            </xsl:apply-templates>
            <xsl:apply-templates>
              <xsl:with-param name="context" select="$context"/>
            </xsl:apply-templates>
            <xsl:apply-templates select="." mode="end">
              <xsl:with-param name="context" select="$context"/>
            </xsl:apply-templates>
            <xsl:text>&#x0A;</xsl:text>
          </div>
          <xsl:text>&#x0A;</xsl:text>
        </section>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- add navigation role to navbar -->
  <xsl:template match="/" mode="navbar">
    <xsl:choose>
      <xsl:when test="$GITBOOK">
        <nav class="ltx_page_navbar">
          <xsl:apply-templates select="//ltx:navigation/ltx:TOC"/>
          <xsl:text>&#x0A;</xsl:text>
        </nav>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- remove wrappers around navigation TOC -->
  <xsl:template match="ltx:navigation/ltx:TOC">
    <xsl:param name="context"/>
    <xsl:choose>
      <xsl:when test="$GITBOOK">
        <xsl:if test="ltx:toclist/descendant::ltx:tocentry">
          <xsl:text>&#x0A;</xsl:text>
          <xsl:apply-templates>
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- add class summary and link to the front page to top navigation TOC -->
  <xsl:template match="ltx:navigation/ltx:TOC/ltx:toclist">
    <xsl:param name="context"/>
    <xsl:choose>
      <xsl:when test="$GITBOOK">
        <ul>
          <xsl:call-template name='add_id'/>
          <xsl:call-template name='add_attributes'>
            <xsl:with-param name="extra_classes">summary</xsl:with-param>
          </xsl:call-template>
          <li>
            <xsl:text>&#x0A;</xsl:text>
            <xsl:choose>
              <!-- link to the front page -->
              <xsl:when test="//ltx:navigation/ltx:ref[@rel='start']">
                <xsl:for-each select="//ltx:navigation/ltx:ref[@rel='start']">
                  <a href="{f:url(@href)}" title="{@title}">
                    <xsl:variable name="innercontext" select="'inline'"/>
                    <xsl:call-template name="add_id"/>
                    <xsl:call-template name="add_attributes"/>
                    <xsl:apply-templates select="." mode="begin">
                      <xsl:with-param name="context" select="$innercontext"/>
                    </xsl:apply-templates>
                    <xsl:apply-templates select="node()">
                      <xsl:with-param name="context" select="$innercontext"/>
                    </xsl:apply-templates>
                    <xsl:apply-templates select="." mode="end">
                      <xsl:with-param name="context" select="$innercontext"/>
                    </xsl:apply-templates>
                  </a>
                </xsl:for-each>
              </xsl:when>
              <!-- unless we *are* the front page -->
              <xsl:otherwise>
                <xsl:variable name="title" select="f:if(/ltx:document/ltx:toctitle!='',/ltx:document/ltx:toctitle,/ltx:document/ltx:title)"/>
                <a href="" title="{$title}" class="ltx_ref">
                  <xsl:value-of select="$title"/>
                </a>
              </xsl:otherwise>
            </xsl:choose>
          </li>
          <li class="divider"/>
          <xsl:apply-templates>
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
        </ul>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- add appendix/chapter class to navigation TOC entries and 'Appendix' divider -->
  <xsl:template match="ltx:navigation//ltx:tocentry">
    <xsl:param name="context"/>
    <xsl:choose>
      <xsl:when test="$GITBOOK">
        <xsl:text>&#x0A;</xsl:text>
        <!-- TODO: figure out what data-level, data-path are for -->
        <li data-level="{ltx:ref//ltx:tag[1]/text()}"
            data-path="{b:url-without-fragment(ltx:ref/@href)}">
          <xsl:call-template name='add_id'/>
          <xsl:call-template name='add_attributes'>
            <xsl:with-param name="extra_classes">
              <xsl:value-of select="f:if(b:has-class('ltx_toc_appendix'),' appendix ',' chapter ')"/>
              <xsl:if test="b:has-class('ltx_ref_self')">active</xsl:if>
            </xsl:with-param>
          </xsl:call-template>
          <xsl:apply-templates>
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
        </li>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- insert <a href=""> for navigation TOC entries without href (i.e., the page itself) -->
  <xsl:template match="ltx:navigation/ltx:TOC//ltx:ref[not(@href)]">
    <xsl:param name="context"/>
    <xsl:choose>
      <xsl:when test="$GITBOOK">
        <!-- TODO: is there *any* way to get the current filename? it may be impossible -->
        <a href="" title="{@title}">
          <xsl:variable name="innercontext" select="'inline'"/>
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
        </a>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- do not wrap titles -->
  <xsl:template match="ltx:navigation//ltx:text[@class='ltx_ref_title']">
    <xsl:param name="context"/>
    <xsl:choose>
      <xsl:when test="$GITBOOK">
        <xsl:apply-templates>
          <xsl:with-param name="context" select="$context"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- wrap section number with <b> -->
  <xsl:template match="ltx:navigation/ltx:TOC//ltx:tag">
    <xsl:param name="context"/>
    <xsl:choose>
      <xsl:when test="$GITBOOK">
        <b><xsl:apply-imports/></b>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- the header becomes the gitbook toolbar -->
  <xsl:template match="/" mode="header">
    <xsl:choose>
      <xsl:when test="$GITBOOK">
        <div class="book-header fixed" role="navigation">
          <h1>
            <xsl:choose>
              <xsl:when test="/ltx:*/ltx:tocticle">
                <xsl:value-of select="/ltx:*/ltx:toctitle/text()"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="/ltx:*/ltx:title/text()"/>
              </xsl:otherwise>
            </xsl:choose>
          </h1>
        </div>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- remove footer -->
  <xsl:template match="/" mode="footer">
    <xsl:choose>
      <xsl:when test="$GITBOOK"/>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- add header-section-number and move trailing characters (period, space) outside of the tag -->
  <xsl:template match="ltx:title/ltx:tag">
    <xsl:param name="context"/>
    <xsl:choose>
      <xsl:when test="$GITBOOK">
        <span>
          <xsl:variable name="innercontext" select="'inline'"/><!-- override -->
          <xsl:call-template name="add_attributes">
            <xsl:with-param name="extra_classes">header-section-number</xsl:with-param>
          </xsl:call-template>
          <xsl:apply-templates select="." mode="begin">
            <xsl:with-param name="context" select="$innercontext"/>
          </xsl:apply-templates>
          <xsl:value-of select="@open"/>
          <xsl:apply-templates>
            <xsl:with-param name="context" select="$innercontext"/>
          </xsl:apply-templates>
          <xsl:apply-templates select="." mode="end">
            <xsl:with-param name="context" select="$innercontext"/>
          </xsl:apply-templates>
        </span>
        <xsl:value-of select="@close"/>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ensure that block elements wider than the page can be scrolled -->
  <!-- this list is likely not exhaustive -->
  <xsl:template match="ltx:equation[f:countcolumns() &gt; 1] | ltx:equationgroup | ltx:picture | ltx:tabular | ltx:graphics">
    <xsl:param name="context"/>
    <xsl:choose>
      <xsl:when test="$GITBOOK and $context != 'inline'">
        <div class="bml-overflow-wrapper">
          <xsl:apply-imports/>
        </div>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- adjust the document sectioning level when $GITBOOK -->
  <func:function name="f:seclev-aux">
    <xsl:param name="name"/>
    <func:result>
      <xsl:choose>
        <xsl:when test="$name = 'document' and $GITBOOK">0</xsl:when>
        <xsl:when test="$name = 'document' and not($GITBOOK)">1</xsl:when>
        <xsl:when test="$name = 'part'"><!-- The logic: 1+doc level, if there IS a ltx:document-->
<!--          <xsl:value-of select="f:seclev-aux('document')+number(boolean(//ltx:document/ltx:title))"/>-->
          <!-- but if we are $GITBOOK, shift back up by one -->
          <xsl:value-of select="f:seclev-aux('document')+number(boolean(//ltx:document) or $GITBOOK)"/>
        </xsl:when>
        <xsl:when test="$name = 'chapter'">
          <xsl:value-of select="f:seclev-aux('part')+number(boolean(//ltx:part/ltx:title))"/>
        </xsl:when>
        <xsl:when test="$name = 'section'">
          <xsl:value-of select="f:seclev-aux('chapter')+number(boolean(//ltx:chapter/ltx:title))"/>
        </xsl:when>
        <!-- These are same level as chapter, if there IS a chapter, otherwise same as section-->
        <xsl:when test="$name = 'appendix' or $name = 'index'
                        or $name = 'glossary' or $name = 'bibliography'">
          <xsl:value-of
              select="f:if(//ltx:chapter,f:seclev-aux('chapter'),f:seclev-aux('section'))"/>
        </xsl:when>
        <xsl:when test="$name = 'subsection'"> <!--Weird? (could be in appendix!)-->
          <xsl:value-of select="f:seclev-aux('section')
                                +number(boolean(//ltx:section/ltx:title | //ltx:appendix/ltx:title))"/>
        </xsl:when>
        <xsl:when test="$name = 'subsubsection'">
          <xsl:value-of select="f:seclev-aux('subsection')
                                +number(boolean(//ltx:subsection/ltx:title))"/>
        </xsl:when>
        <xsl:when test="$name = 'paragraph'">
          <xsl:value-of select="f:seclev-aux('subsubsection')
                                +number(boolean(//ltx:subsubsection/ltx:title))"/>
        </xsl:when>
        <xsl:when test="$name = 'subparagraph'">
          <xsl:value-of select="f:seclev-aux('paragraph')
                                +number(boolean(//ltx:paragraph/ltx:title))"/>
        </xsl:when>
        <xsl:when test="$name = 'theorem' or $name = 'proof'">6</xsl:when> <!--what else?-->
      </xsl:choose>
    </func:result>
  </func:function>

</xsl:stylesheet>
