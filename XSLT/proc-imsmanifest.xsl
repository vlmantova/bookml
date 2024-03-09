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
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:ltx="http://dlmf.nist.gov/LaTeXML"
  xmlns="http://www.imsglobal.org/xsd/imscp_v1p1"
  xmlns:adlcp="http://www.adlnet.org/xsd/adlcp_v1p3"
  xmlns:lom="http://ltsc.ieee.org/xsd/LOM"
  xmlns:exsl="http://exslt.org/common"
  exclude-result-prefixes="ltx"
  extension-element-prefixes="exsl">
  <!-- xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" -->

  <xsl:output
    method="xml"
    encoding="utf-8"
    cdata-section-elements="lom:entity" />

  <xsl:param name="BML_MANIFEST" select="''" />

  <xsl:template match="/">
    <xsl:apply-templates select="ltx:document" />
  </xsl:template>

  <xsl:template match="/ltx:document">
    <manifest identifier="com.github.io.vlmantova.bookml.SCORM">
      <!-- xsi:schemaLocation="http://www.imsglobal.org/xsd/imscp_v1p1 imscp_v1p1.xsd
                          http://ltsc.ieee.org/xsd/LOM lom.xsd
                          http://www.adlnet.org/xsd/adlcp_v1p3 adlcp_v1p3.xsd" -->
      <xsl:copy-of select="@xml:lang" />
      <xsl:if test="ltx:date[@role='creation']">
        <xsl:attribute name="version">
          <xsl:value-of select="ltx:date[@role='creation']" />
        </xsl:attribute>
      </xsl:if>
      <metadata>
        <schema>ADL SCORM</schema>
        <schemaversion>2004 3rd Edition</schemaversion>
        <lom:lom>
          <lom:general>
            <xsl:apply-templates select="ltx:title" mode="lom" />
            <xsl:if test="not(ltx:rdf[@property='dcterms:subject'])">
              <xsl:apply-templates select="ltx:abstract" />
            </xsl:if>
            <xsl:apply-templates select="ltx:rdf" />
          </lom:general>
          <lom:lifeCycle>
            <xsl:apply-templates select="ltx:creator[ltx:personname]" />
            <xsl:apply-templates select="ltx:date[@role='creation']" />
          </lom:lifeCycle>
        </lom:lom>
      </metadata>
      <organizations>
        <organization identifier="org1">
          <xsl:apply-templates select="ltx:title" />
          <item identifier="item1" identifierref="resource1">
            <xsl:apply-templates select="ltx:title" />
          </item>
        </organization>
      </organizations>
      <resources>
        <resource identifier="resource1" type="webcontent" adlcp:scormType="asset">
          <xsl:variable name="files">
            <xsl:for-each select="document($BML_MANIFEST,.)/manifest/file">
              <file href="{text()}" />
            </xsl:for-each>
          </xsl:variable>
          <xsl:attribute name="href">
            <xsl:value-of select="exsl:node-set($files)/*[1]/@href" />
          </xsl:attribute>
          <xsl:copy-of select="$files" />
        </resource>
      </resources>
    </manifest>
  </xsl:template>

  <xsl:template match="ltx:title">
    <title>
      <xsl:apply-templates />
    </title>
  </xsl:template>

  <xsl:template match="ltx:title" mode="lom">
    <lom:title>
      <lom:string>
        <xsl:apply-templates />
      </lom:string>
    </lom:title>
  </xsl:template>

  <xsl:template match="ltx:rdf" />
  <xsl:template match="ltx:rdf[@property='dcterms:subject']">
    <lom:description>
      <lom:string>
        <xsl:value-of select="@content" />
      </lom:string>
    </lom:description>
  </xsl:template>

  <xsl:template match="ltx:abstract">
    <lom:description>
      <lom:string>
        <xsl:apply-templates />
      </lom:string>
    </lom:description>
  </xsl:template>

  <xsl:template match="ltx:creator">
    <lom:contribute>
      <lom:role>
        <lom:value>
          <xsl:value-of select="@role" />
        </lom:value>
      </lom:role>
      <lom:entity>
        <xsl:text>BEGIN:VCARD VERSION:2.1&#x0A;FN:</xsl:text>
        <xsl:apply-templates select="ltx:personname" />
        <xsl:text>&#x0A;END:VCARD</xsl:text>
      </lom:entity>
    </lom:contribute>
  </xsl:template>

  <xsl:template match="ltx:date">
    <lom:version>
      <lom:string>
        <xsl:apply-templates />
      </lom:string>
    </lom:version>
  </xsl:template>

  <xsl:template match="ltx:tags/ltx:tag[position() > 1]" />

</xsl:stylesheet>
