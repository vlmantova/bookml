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
  xmlns="http://www.imsproject.org/xsd/imscp_rootv1p1p2"
  xmlns:adlcp="http://www.adlnet.org/xsd/adlcp_rootv1p2">

  <xsl:output
    method="xml"
    encoding="utf-8"
    cdata-section-elements="entity" />

  <xsl:template match="/ltx:document">
    <manifest identifier="com.github.io.vlmantova.bookml.SCORM">
      <xsl:copy-of select="@xml:lang" />
      <xsl:if test="ltx:date[@role='creation']">
        <xsl:attribute name="version">
          <xsl:value-of select="ltx:date[@role='creation']" />
        </xsl:attribute>
      </xsl:if>
      <metadata>
        <schema>ADL SCORM</schema>
        <schemaversion>2004 3rd Edition</schemaversion>
        <lom>
          <general>
            <xsl:apply-templates select="ltx:title" />
            <xsl:apply-templates select="ltx:abstract" />
          </general>
          <lifeCycle>
            <xsl:apply-templates select="ltx:creator[ltx:personname]" />
            <xsl:apply-templates select="ltx:date[@role='creation']" />
          </lifeCycle>
        </lom>
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
        <resource identifier="resource1" type="webcontent" href="index.html" adlcp:scormtype="sco">
          <file href="index.html" />
        </resource>
      </resources>
    </manifest>
  </xsl:template>

  <xsl:template match="ltx:title">
    <title>
      <xsl:apply-templates />
    </title>
  </xsl:template>

  <xsl:template match="ltx:abstract">
    <description>
      <langString>
        <xsl:apply-templates />
      </langString>
    </description>
  </xsl:template>

  <xsl:template match="ltx:creator">
    <contribute>
      <role>
        <xsl:value-of select="@role" />
      </role>
      <entity>
        <xsl:text>BEGIN:VCARD VERSION:2.1&#x0A;FN:</xsl:text>
        <xsl:apply-templates select="ltx:personname" />
        <xsl:text>&#x0A;END:VCARD</xsl:text>
      </entity>
    </contribute>
  </xsl:template>

  <xsl:template match="ltx:date">
    <version>
      <langString>
        <xsl:apply-templates />
      </langString>
    </version>
  </xsl:template>

</xsl:stylesheet>
