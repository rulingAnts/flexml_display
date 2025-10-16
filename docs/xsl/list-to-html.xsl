<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" encoding="UTF-8" indent="yes"/>

  <!-- Root template for lists container -->
  <xsl:template match="/lists">
    <div>
      <xsl:apply-templates select="list"/>
    </div>
  </xsl:template>

  <!-- Root template for single list -->
  <xsl:template match="/list">
    <xsl:call-template name="render-list"/>
  </xsl:template>

  <!-- Template to render a list -->
  <xsl:template name="render-list">
    <div>
      <!-- Title: prefer Name or name inside the list -->
      <div class="section-title">
        <xsl:choose>
          <xsl:when test="name">
            <xsl:value-of select="normalize-space(name)"/>
          </xsl:when>
          <xsl:when test="Name">
            <xsl:value-of select="normalize-space(Name)"/>
          </xsl:when>
          <xsl:when test="Name/str">
            <xsl:value-of select="normalize-space(Name/str)"/>
          </xsl:when>
          <xsl:when test="name/str">
            <xsl:value-of select="normalize-space(name/str)"/>
          </xsl:when>
          <xsl:otherwise>List</xsl:otherwise>
        </xsl:choose>
      </div>

      <!-- Build the item tree -->
      <ul class="tree">
        <xsl:apply-templates select="item | letitem | sditem | items/item | items/letitem | items/sditem"/>
      </ul>
    </div>
  </xsl:template>

  <!-- Template for list items -->
  <xsl:template match="item | letitem | sditem">
    <li>
      <!-- Toggle indicator -->
      <xsl:variable name="has-children" select="count(item | letitem | sditem | subitems/item | subitems/letitem | subitems/sditem) &gt; 0"/>
      <span class="toggle">
        <xsl:if test="$has-children">
          <xsl:attribute name="style">cursor: pointer</xsl:attribute>
        </xsl:if>
        <xsl:choose>
          <xsl:when test="$has-children">▾</xsl:when>
          <xsl:otherwise><xsl:text> </xsl:text></xsl:otherwise>
        </xsl:choose>
      </span>

      <!-- Item name and abbreviation -->
      <xsl:variable name="item-name">
        <xsl:choose>
          <xsl:when test="name">
            <xsl:value-of select="normalize-space(name)"/>
          </xsl:when>
          <xsl:when test="Name">
            <xsl:value-of select="normalize-space(Name)"/>
          </xsl:when>
          <xsl:when test="@name">
            <xsl:value-of select="@name"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="local-name()"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:variable name="abbr">
        <xsl:choose>
          <xsl:when test="abbr">
            <xsl:value-of select="normalize-space(abbr)"/>
          </xsl:when>
          <xsl:when test="Abbreviation">
            <xsl:value-of select="normalize-space(Abbreviation)"/>
          </xsl:when>
          <xsl:when test="@abbr">
            <xsl:value-of select="@abbr"/>
          </xsl:when>
          <xsl:when test="@ws">
            <xsl:value-of select="@ws"/>
          </xsl:when>
        </xsl:choose>
      </xsl:variable>

      <xsl:value-of select="$item-name"/>
      <xsl:if test="string-length($abbr) &gt; 0">
        <xsl:text> (</xsl:text>
        <xsl:value-of select="$abbr"/>
        <xsl:text>)</xsl:text>
      </xsl:if>

      <!-- Nested items -->
      <xsl:if test="$has-children">
        <ul class="tree">
          <xsl:apply-templates select="item | letitem | sditem | subitems/item | subitems/letitem | subitems/sditem"/>
        </ul>
      </xsl:if>
    </li>
  </xsl:template>

</xsl:stylesheet>
