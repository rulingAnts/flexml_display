<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="html" encoding="UTF-8" indent="yes"/>

  <!-- ========================
       CSS / style variables
       ======================== -->
  <xsl:variable name="css">
<![CDATA[
:root{
  --cell-border: 1px solid #ccc;
  --header-border-thick: 3px solid #444;
  --row-end-border: 2px solid #666;
  --para-end-border: 4px solid #333;
  --font-family: system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial;
  --font-size: 14px;
  --gloss-color: #666;
  --dependent-color: #0b60d6;
  --speech-color: #127a2d;
  --song-color: #6b2fa8;
  --listref-color: #d97706;
  --clausemkr-color: #0a8a3f;
  --rownum-color: #000;
  --note-color: #444;
  --cell-padding: 6px 8px;
  --interlinear-gap: 0.35em;
}

/* ================= Table Layout ================= */
.chartshell {
  border-collapse: separate;
  border-spacing: 0;
  width: 100%;
  font-family: var(--font-family);
  font-size: var(--font-size);
  margin: 1em 0;
}

/* colgroup-based thick borders */
colgroup[class^="group"] col {
  border-left: none;
  border-right: none;
}
colgroup.group1 col:first-child {
  border-left: var(--header-border-thick);
}
colgroup[class^="group"]:last-of-type col:last-child {
  border-right: var(--header-border-thick);
}
colgroup.group1 col,
colgroup.group2 col,
colgroup.group3 col,
colgroup.group4 col,
colgroup.group5 col {
  border-right: var(--header-border-thick);
}
.chartshell th, .chartshell td {
  border: var(--cell-border);
  padding: var(--cell-padding);
  vertical-align: top;
}

/* Title rows */
.row.title1 th { background: #f6f6f6; border-top: var(--header-border-thick); border-bottom: var(--header-border-thick); }
.row.title2 th { background: #fbfbfb; border-right: var(--header-border-thick); }

/* Row type colors */
.row.dependent { color: var(--dependent-color); }
.row.speech { color: var(--speech-color); }
.row.song { color: var(--song-color); }

/* Sentence/paragraph boundaries */
.row.endSent { border-bottom: var(--row-end-border); }
.row.endPara { border-bottom: var(--para-end-border); }

/* reversed cell alignment */
.cell.reversed { text-align: right; }

/* interlinear layout */
.interlinear {
  display: inline-grid;
  grid-auto-flow: column;
  grid-auto-columns: max-content;
  grid-template-rows: auto auto;
  gap: 0 var(--interlinear-gap);
  white-space: normal;
  align-items: start;
}
.interlinear .w { grid-row: 1; }
.interlinear .g { grid-row: 2; font-size: 0.9em; color: var(--gloss-color); }

/* small token classes */
.listRef { color: var(--listref-color); font-weight: 600; }
.clauseMkr { color: var(--clausemkr-color); font-weight: 600; }
.rownum { color: var(--rownum-color); font-weight: 600; margin-right: 0.25em; }
.note { color: var(--note-color); font-style: italic; }

/* ================= Group vertical borders (per-cell) ================= */
/* Draw thick right borders at the end of each header-defined group */
.chartshell th.group-end, .chartshell td.group-end {
  border-right: var(--header-border-thick);
}
/* Avoid double lines: default remove left border for group starts... */
.chartshell th.group-start, .chartshell td.group-start {
  border-left: 0;
}
/* ...but keep a thick left border on the first column of the table */
.chartshell tr > .group-start:first-child {
  border-left: var(--header-border-thick);
}
]]>
  </xsl:variable>

  <!-- ===========================
       Helper: emit <style>
       =========================== -->
  <xsl:template name="emit-style">
    <style>
      <xsl:value-of select="$css" disable-output-escaping="yes"/>
    </style>
  </xsl:template>

  <!-- ===========================
       Helper: emit metadata comment
       =========================== -->
  <xsl:template name="emit-metadata-comment">
    <xsl:if test="/document/languages">
      <xsl:comment>
        <xsl:text>Languages: </xsl:text>
        <xsl:for-each select="/document/languages/*">
          <xsl:value-of select="name()"/>=<xsl:value-of select="."/>
          <xsl:if test="position()!=last()">; </xsl:if>
        </xsl:for-each>
      </xsl:comment>
    </xsl:if>
  </xsl:template>

  <!-- ===========================
       Root template
       =========================== -->
  <xsl:template match="/">
    <html>
      <head>
        <meta charset="utf-8"/>
        <title>Chart → HTML</title>
        <xsl:call-template name="emit-style"/>
      </head>
      <body>
        <xsl:call-template name="emit-metadata-comment"/>

        <div class="chartshell-wrapper">
          <table class="chartshell">
            <!-- emit colgroups -->
            <xsl:call-template name="emit-colgroups"/>
            <!-- emit body rows -->
            <xsl:apply-templates select="document/chart"/>
          </table>
        </div>
      </body>
    </html>
  </xsl:template>

  <!-- ===========================
       Emit <colgroup> elements
       =========================== -->
  <xsl:template name="emit-colgroups">
    <xsl:variable name="header" select="document/chart/row[@type='title1'][1]"/>
    <xsl:if test="$header">
      <!-- In XSLT 1.0, union '|' expects node-sets; avoid mixing with numbers -->
      <xsl:variable name="cols-total" select="sum($header/cell/@cols) + count($header/cell[not(@cols)])"/>
      <xsl:variable name="groupCount" select="count($header/cell)"/>
      <xsl:for-each select="$header/cell">
        <xsl:variable name="span" select="number(@cols)"/>
        <colgroup>
          <xsl:attribute name="class">
            <xsl:text>group</xsl:text><xsl:value-of select="position()"/>
          </xsl:attribute>
          <col>
            <xsl:attribute name="span">
              <xsl:choose>
                <xsl:when test="@cols"><xsl:value-of select="$span"/></xsl:when>
                <xsl:otherwise>1</xsl:otherwise>
              </xsl:choose>
            </xsl:attribute>
          </col>
        </colgroup>
      </xsl:for-each>
    </xsl:if>
  </xsl:template>

  <!-- chart → tbody -->
  <xsl:template match="chart">
    <tbody>
      <xsl:apply-templates select="row"/>
    </tbody>
  </xsl:template>

  <!-- row -->
  <xsl:template match="row">
    <xsl:variable name="rclass">
      <xsl:value-of select="concat('row ', translate(@type,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz'))"/>
    </xsl:variable>
    <xsl:variable name="extra">
      <xsl:choose>
        <xsl:when test="@endPara='true'"> endPara</xsl:when>
        <xsl:when test="@endSent='true'"> endSent</xsl:when>
        <xsl:otherwise/>
      </xsl:choose>
    </xsl:variable>

    <tr>
      <xsl:attribute name="class">
        <xsl:value-of select="concat($rclass, $extra)"/>
      </xsl:attribute>
      <xsl:apply-templates select="cell"/>
    </tr>
  </xsl:template>

  <!-- cell -->
  <xsl:template match="cell">
    <xsl:variable name="isHeader" select="parent::row[@type='title1' or @type='title2']"/>
    <xsl:variable name="tag">
      <xsl:choose>
        <xsl:when test="$isHeader">th</xsl:when>
        <xsl:otherwise>td</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <!-- Compute absolute column start/end indices for this cell -->
    <xsl:variable name="colStart" select="sum(preceding-sibling::cell/@cols) + count(preceding-sibling::cell[not(@cols)]) + 1"/>
    <xsl:variable name="span">
      <xsl:choose>
        <xsl:when test="@cols"><xsl:value-of select="@cols"/></xsl:when>
        <xsl:otherwise>1</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="colEnd" select="$colStart + number($span) - 1"/>
    <!-- Determine if this cell sits at a group boundary based on the first title row -->
    <xsl:variable name="isGroupEnd">
      <xsl:for-each select="/document/chart/row[@type='title1'][1]/cell">
        <xsl:variable name="hStart" select="sum(preceding-sibling::cell/@cols) + count(preceding-sibling::cell[not(@cols)]) + 1"/>
        <xsl:variable name="hSpan">
          <xsl:choose>
            <xsl:when test="@cols"><xsl:value-of select="@cols"/></xsl:when>
            <xsl:otherwise>1</xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:variable name="hEnd" select="$hStart + number($hSpan) - 1"/>
        <xsl:if test="number($hEnd) = number($colEnd)">X</xsl:if>
      </xsl:for-each>
    </xsl:variable>
    <xsl:variable name="isGroupStart">
      <!-- First column is always a group start -->
      <xsl:if test="$colStart = 1">X</xsl:if>
      <!-- Also a start if the previous column was a group end -->
      <xsl:for-each select="/document/chart/row[@type='title1'][1]/cell">
        <xsl:variable name="hStart" select="sum(preceding-sibling::cell/@cols) + count(preceding-sibling::cell[not(@cols)]) + 1"/>
        <xsl:variable name="hSpan">
          <xsl:choose>
            <xsl:when test="@cols"><xsl:value-of select="@cols"/></xsl:when>
            <xsl:otherwise>1</xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:variable name="hEnd" select="$hStart + number($hSpan) - 1"/>
        <xsl:if test="number($hEnd) = number($colStart - 1)">X</xsl:if>
      </xsl:for-each>
    </xsl:variable>
    <xsl:element name="{$tag}">
      <xsl:if test="@cols">
        <xsl:attribute name="colspan"><xsl:value-of select="@cols"/></xsl:attribute>
      </xsl:if>
      <xsl:attribute name="class">
        <xsl:text>cell</xsl:text>
        <xsl:if test="@reversed='true'"> reversed</xsl:if>
        <xsl:if test="string-length($isGroupStart) &gt; 0"> group-start</xsl:if>
        <xsl:if test="string-length($isGroupEnd) &gt; 0"> group-end</xsl:if>
      </xsl:attribute>
      <!-- Render interlinear content; no fallback glosses -->
      <xsl:apply-templates select="main"/>
    </xsl:element>
  </xsl:template>

  <!-- main: interlinear text -->
  <xsl:template match="main">
    <div class="interlinear">
      <xsl:for-each select="*">
        <xsl:choose>
          <xsl:when test="name()='word'">
            <xsl:variable name="wi" select="count(preceding-sibling::word)+1"/>
            <span class="w"><xsl:value-of select="."/></span>
            <span class="g"><xsl:value-of select="../following-sibling::glosses[1]/gloss[$wi] | ../glosses/gloss[$wi]"/></span>
          </xsl:when>
          <xsl:when test="name()='lit'">
            <span class="w"><xsl:value-of select="."/></span><span class="g"/>
          </xsl:when>
          <xsl:when test="name()='listRef'">
            <span class="w listRef"><xsl:value-of select="."/></span><span class="g"/>
          </xsl:when>
          <xsl:when test="name()='clauseMkr'">
            <span class="w clauseMkr"><xsl:value-of select="."/></span><span class="g"/>
          </xsl:when>
          <xsl:when test="name()='rownum'">
            <span class="w rownum"><xsl:value-of select="."/></span><span class="g"/>
          </xsl:when>
          <xsl:when test="name()='note'">
            <span class="w note"><xsl:value-of select="."/></span><span class="g"/>
          </xsl:when>
          <xsl:otherwise>
            <span class="w"><xsl:value-of select="."/></span><span class="g"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </div>
  </xsl:template>

  <!-- No explicit glosses template; glosses are consumed by interlinear mapping only. -->
</xsl:stylesheet>