<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="html" encoding="UTF-8" indent="yes"/>

  <!-- ========================
       CSS / style variables
       Edit these at the top
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
  --dependent-color: #0b60d6; /* blue */
  --speech-color: #127a2d;    /* green */
  --song-color: #6b2fa8;      /* purple */
  --listref-color: #d97706;   /* orange */
  --clausemkr-color: #0a8a3f;  /* green for clause markers */
  --rownum-color: #000;
  --note-color: #444;
  --cell-padding: 6px 8px;
  --interlinear-gap: 0.35em;
}

/* Basic table appearance */
.chartshell { font-family: var(--font-family); font-size: var(--font-size); margin: 1em 0; border-collapse: collapse; width: 100%; }
.chartshell th, .chartshell td { border: var(--cell-border); padding: var(--cell-padding); vertical-align: top; }

/* Title rows */
.row.title1 th { border: var(--header-border-thick); background: #f6f6f6; }
.row.title2 th { border-right: var(--header-border-thick); background: #fbfbfb; }

/* Row type classes */
.row.normal { }
.row.dependent { color: var(--dependent-color); }
.row.speech { color: var(--speech-color); }
.row.song { color: var(--song-color); }

/* end sentence / paragraph */
.row.endSent { border-bottom: var(--row-end-border); }
.row.endPara { border-bottom: var(--para-end-border); }

/* reversed cell alignment */
.cell.reversed { text-align: right; }

/* Interlinear layout:
   For each "token" (word, lit, listRef, clauseMkr, rownum, possibly others)
   we produce paired spans: .w (word-line) and .g (gloss-line).
   The interlinear container uses inline-grid so columns align.
*/
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

/* thin gray borders default between table cells (already set on th/td via .chartshell) */
]]>
  </xsl:variable>

  <!-- ============ Helper templates ============ -->

  <!-- Output the style block -->
  <xsl:template name="emit-style">
    <style>
      <xsl:value-of select="$css" disable-output-escaping="yes"/>
    </style>
  </xsl:template>

  <!-- comment in HTML with language metadata if available -->
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
       Main: produce an HTML page
       =========================== -->
  <xsl:template match="/">
    <html>
      <head>
        <meta charset="utf-8"/>
        <title>Chart → HTML</title>
        <xsl:call-template name="emit-style"/>
      </head>
      <body>
        <!-- languages/metadata comment -->
        <xsl:call-template name="emit-metadata-comment"/>

        <div class="chartshell-wrapper">
          <table class="chartshell" role="table">
            <xsl:apply-templates select="document/chart"/>
          </table>
        </div>
      </body>
    </html>
  </xsl:template>

  <!-- chart → tbody + rows -->
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
      <!-- apply each cell -->
      <xsl:apply-templates select="cell"/>
    </tr>
  </xsl:template>

  <!-- cell: decide th vs td based on ancestor row type -->
  <xsl:template match="cell">
    <xsl:variable name="isHeader" select="parent::row[@type='title1' or @type='title2']"/>
    <xsl:choose>
      <xsl:when test="$isHeader">
        <th>
          <xsl:if test="@cols">
            <xsl:attribute name="colspan"><xsl:value-of select="@cols"/></xsl:attribute>
          </xsl:if>
          <xsl:attribute name="class">
            <xsl:if test="@reversed='true'">cell reversed</xsl:if>
            <xsl:if test="not(@reversed='true')">cell</xsl:if>
          </xsl:attribute>
          <xsl:apply-templates select="main|glosses"/>
        </th>
      </xsl:when>
      <xsl:otherwise>
        <td>
          <xsl:if test="@cols">
            <xsl:attribute name="colspan"><xsl:value-of select="@cols"/></xsl:attribute>
          </xsl:if>
          <xsl:attribute name="class">
            <xsl:if test="@reversed='true'">cell reversed</xsl:if>
            <xsl:if test="not(@reversed='true')">cell</xsl:if>
          </xsl:attribute>
          <xsl:apply-templates select="main|glosses"/>
        </td>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- main: render interlinear tokens
       Strategy: iterate children of main in document order.
       For each child token we output:
         - a span.w in grid-row 1 with token text
         - a corresponding span.g in grid-row 2 (for word tokens we pull matching gloss by index, otherwise empty)
  -->
  <xsl:template match="main">
    <div class="interlinear">
      <!-- iterate tokens: word, lit, listRef, clauseMkr, rownum, note (others just output) -->
      <xsl:for-each select="*">
        <xsl:choose>
          <!-- WORD token -->
          <xsl:when test="name()='word'">
            <!-- compute which word index this is within this 'main' -->
            <xsl:variable name="wi" select="count(preceding-sibling::word) + 1"/>
            <span class="w">
              <xsl:value-of select="."/>
              <!-- add (no)space logic: if this element has @noSpaceAfter='true' OR next sibling has @noSpaceBefore='true', don't emit space -->
              <xsl:if test="not(@noSpaceAfter='true' or following-sibling::*[1][@noSpaceBefore='true'])">
                <xsl:text> </xsl:text>
              </xsl:if>
            </span>
            <span class="g">
              <!-- pick corresponding gloss from the sibling glosses element in the same cell -->
              <xsl:value-of select="../following-sibling::glosses[1]/gloss[$wi] | ../glosses/gloss[$wi]"/>
            </span>
          </xsl:when>

          <!-- LIT token (punctuation or bracket) -->
          <xsl:when test="name()='lit'">
            <span class="w">
              <xsl:value-of select="."/>
              <xsl:if test="not(@noSpaceAfter='true' or following-sibling::*[1][@noSpaceBefore='true'])">
                <xsl:text> </xsl:text>
              </xsl:if>
            </span>
            <span class="g"/><!-- empty gloss cell -->
          </xsl:when>

          <!-- listRef -->
          <xsl:when test="name()='listRef'">
            <span class="w listRef">
              <xsl:value-of select="."/>
              <xsl:if test="not(@noSpaceAfter='true' or following-sibling::*[1][@noSpaceBefore='true'])">
                <xsl:text> </xsl:text>
              </xsl:if>
            </span>
            <span class="g"/>
          </xsl:when>

          <!-- clauseMkr -->
          <xsl:when test="name()='clauseMkr'">
            <span class="w clauseMkr">
              <xsl:value-of select="."/>
              <xsl:if test="not(@noSpaceAfter='true' or following-sibling::*[1][@noSpaceBefore='true'])">
                <xsl:text> </xsl:text>
              </xsl:if>
            </span>
            <span class="g"/>
          </xsl:when>

          <!-- rownum -->
          <xsl:when test="name()='rownum'">
            <span class="w rownum">
              <xsl:value-of select="."/>
              <xsl:if test="not(@noSpaceAfter='true' or following-sibling::*[1][@noSpaceBefore='true'])">
                <xsl:text> </xsl:text>
              </xsl:if>
            </span>
            <span class="g"/>
          </xsl:when>

          <!-- note -->
          <xsl:when test="name()='note'">
            <span class="w note">
              <xsl:value-of select="."/>
            </span>
            <span class="g"/>
          </xsl:when>

          <!-- fallback for unexpected children -->
          <xsl:otherwise>
            <span class="w">
              <xsl:value-of select="."/>
            </span>
            <span class="g"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </div>
  </xsl:template>

  <!-- glosses: some cells may have a glosses element alone (we handled most gloss output in the word path),
       but if we encounter glosses outside expected flow, we still emit a fallback -->
  <xsl:template match="glosses">
    <div class="glosses-fallback">
      <xsl:for-each select="gloss">
        <span class="g"><xsl:value-of select="."/></span>
      </xsl:for-each>
    </div>
  </xsl:template>

</xsl:stylesheet>