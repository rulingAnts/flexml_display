<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="html" encoding="UTF-8" indent="yes"/>

  <!-- Debug toggle: when 'true', visible warning messages are shown in cells with data issues. -->
  <xsl:param name="debug" select="'false'"/>

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
  /* Configurable width for the last column (typically Notes) */
  --notes-col-width: 24ch;
}

/* ================= Table Layout ================= */
.chartshell {
  border-collapse: separate;
  border-spacing: 0;
  width: 100%;
  font-family: var(--font-family);
  font-size: var(--font-size);
  margin: 1em 0;
  /* Fixed layout so explicit column widths are respected and the last column doesn't balloon */
  table-layout: fixed;
}

/* colgroup-based thick borders */
.chartshell colgroup[class^="group"] col {
  border-left: none;
  border-right: none;
}
.chartshell colgroup.group1 col:first-child {
  border-left: var(--header-border-thick);
}
.chartshell colgroup[class^="group"]:last-of-type col:last-child {
  border-right: var(--header-border-thick);
}
.chartshell colgroup.group1 col,
.chartshell colgroup.group2 col,
.chartshell colgroup.group3 col,
.chartshell colgroup.group4 col,
.chartshell colgroup.group5 col {
  border-right: var(--header-border-thick);
}
/* Constrain the width of the final group (typically Notes column) */
.chartshell colgroup[class^="group"]:last-of-type col {
  /* A sane width for notes; adjust as needed */
  width: var(--notes-col-width);
}
.chartshell th, .chartshell td {
  border: var(--cell-border);
  padding: var(--cell-padding);
  vertical-align: top;
}

/* Ensure the last column wraps so it doesn't force the table wider */
.chartshell tr > th:last-child,
.chartshell tr > td:last-child {
  white-space: normal;
  overflow-wrap: anywhere;
  word-break: break-word;
}

/* Title rows */
.chartshell .row.title1 th { background: #f6f6f6; border-top: var(--header-border-thick); border-bottom: var(--header-border-thick); }
.chartshell .row.title2 th { background: #fbfbfb; border-right: var(--header-border-thick); }

/* Row type colors */
.chartshell .row.dependent { color: var(--dependent-color); }
.chartshell .row.speech { color: var(--speech-color); }
.chartshell .row.song { color: var(--song-color); }

/* Sentence/paragraph boundaries */
/* Apply to cells so borders render with separate border model */
.chartshell tr.endSent > th, .chartshell tr.endSent > td { border-bottom: var(--row-end-border); }
.chartshell tr.endPara > th, .chartshell tr.endPara > td { border-bottom: var(--para-end-border); }

/* reversed cell alignment */
.chartshell .cell.reversed { text-align: right; }

.chartshell .interlinear {
  display: inline-flex;
  flex-wrap: wrap;
  align-items: flex-start;
}
.chartshell .interlinear .pair { display: inline-flex; flex-direction: column; align-items: flex-start; min-width: 0; }
.chartshell .interlinear .pair { margin-left: var(--interlinear-gap); }
.chartshell .interlinear .pair:first-child { margin-left: 0; }
/* Keep parentheses/brackets tight with adjacent tokens */
.chartshell .interlinear .pair.punct-open + .pair { margin-left: 0; }
.chartshell .interlinear .pair.punct-close { margin-left: 0; }
.chartshell .interlinear .w { white-space: nowrap; }
.chartshell .interlinear .pair.note .w { white-space: normal; }
.chartshell .interlinear .g { white-space: nowrap; font-size: 0.9em; color: var(--gloss-color); }

/* small token classes */
.chartshell .listRef { color: var(--listref-color); font-weight: 600; }
.chartshell .clauseMkr { color: var(--clausemkr-color); font-weight: 600; }
.chartshell .rownum { color: var(--rownum-color); font-weight: 600; margin-right: 0.25em; }
.chartshell .note { color: var(--note-color); font-style: italic; }

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

/* Debug warnings */
.chartshell .warn { color: #b91c1c; font-style: italic; font-size: 0.9em; }
.warn-no-words-glosses {}
.warn-gloss-count-mismatch {}
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

  <!-- chart → thead + tbody (title rows in thead for print-friendly repeating headers) -->
  <xsl:template match="chart">
    <thead>
      <xsl:apply-templates select="row[@type='title1' or @type='title2']"/>
    </thead>
    <tbody>
      <xsl:apply-templates select="row[not(@type='title1' or @type='title2')]"/>
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

      <!-- Diagnostics: glosses without words, or mismatched counts -->
      <xsl:variable name="wordCount" select="count(main/word)"/>
      <xsl:variable name="glossCount" select="count(glosses/gloss)"/>

      <!-- Always include an HTML comment when issues are detected -->
      <xsl:if test="$glossCount &gt; 0 and $wordCount = 0">
        <xsl:comment> Warning: glosses present with no words (glossCount: <xsl:value-of select="$glossCount"/>) </xsl:comment>
      </xsl:if>
      <xsl:if test="$glossCount &gt; 0 and $wordCount &gt; 0 and $glossCount != $wordCount">
        <xsl:comment> Warning: gloss/word count mismatch (words: <xsl:value-of select="$wordCount"/>, glosses: <xsl:value-of select="$glossCount"/>) </xsl:comment>
      </xsl:if>

      <!-- If debug mode is on, show visible warnings -->
      <xsl:if test="$debug='true' and $glossCount &gt; 0 and $wordCount = 0">
        <div class="warn warn-no-words-glosses">Warning: glosses present with no words.</div>
      </xsl:if>
      <xsl:if test="$debug='true' and $glossCount &gt; 0 and $wordCount &gt; 0 and $glossCount != $wordCount">
        <div class="warn warn-gloss-count-mismatch">Warning: gloss/word count mismatch (words: <xsl:value-of select="$wordCount"/>, glosses: <xsl:value-of select="$glossCount"/>)</div>
      </xsl:if>
    </xsl:element>
  </xsl:template>

  <!-- main: interlinear text -->
  <xsl:template match="main">
    <div class="interlinear">
      <xsl:for-each select="*">
        <xsl:variable name="nm" select="name()"/>
        <xsl:variable name="txt" select="string(.)"/>
        <xsl:variable name="isOpenPunct" select="$nm='lit' and ($txt='(' or $txt='[' or $txt='{')"/>
        <xsl:variable name="isClosePunct" select="$nm='lit' and ($txt=')' or $txt=']' or $txt='}')"/>
        <!-- Skip rendering lit that must attach to neighbors; it will be included by them -->
        <xsl:if test="not($nm='lit' and (@noSpaceAfter='true' or @noSpaceBefore='true'))">
          <span>
            <xsl:attribute name="class">
              <xsl:text>pair</xsl:text>
              <xsl:if test="$nm='listRef'"> <xsl:text> listRef</xsl:text></xsl:if>
              <xsl:if test="$nm='clauseMkr'"> <xsl:text> clauseMkr</xsl:text></xsl:if>
              <xsl:if test="$nm='rownum'"> <xsl:text> rownum</xsl:text></xsl:if>
              <xsl:if test="$nm='note'"> <xsl:text> note</xsl:text></xsl:if>
              <xsl:if test="$isOpenPunct"> <xsl:text> punct-open</xsl:text></xsl:if>
              <xsl:if test="$isClosePunct"> <xsl:text> punct-close</xsl:text></xsl:if>
            </xsl:attribute>
            <!-- Preserve raw listRef label (without adhered punctuation) for downstream UI logic -->
            <xsl:if test="$nm='listRef'">
              <xsl:attribute name="data-listref"><xsl:value-of select="."/></xsl:attribute>
            </xsl:if>
            <xsl:choose>
              <xsl:when test="$nm='word'">
                <xsl:variable name="wi" select="count(preceding-sibling::word)+1"/>
                <span class="w">
                  <xsl:if test="preceding-sibling::*[1][self::lit and @noSpaceAfter='true']">
                    <xsl:value-of select="preceding-sibling::*[1]"/>
                  </xsl:if>
                  <xsl:value-of select="."/>
                  <xsl:if test="following-sibling::*[1][self::lit and @noSpaceBefore='true']">
                    <xsl:value-of select="following-sibling::*[1]"/>
                  </xsl:if>
                </span>
                <span class="g"><xsl:value-of select="../following-sibling::glosses[1]/gloss[$wi] | ../glosses/gloss[$wi]"/></span>
              </xsl:when>
              <xsl:when test="$nm='lit'">
                <!-- Standalone lit (no noSpaceBefore/After) -->
                <span class="w">
                  <xsl:if test="preceding-sibling::*[1][self::lit and @noSpaceAfter='true']">
                    <xsl:value-of select="preceding-sibling::*[1]"/>
                  </xsl:if>
                  <xsl:value-of select="."/>
                  <xsl:if test="following-sibling::*[1][self::lit and @noSpaceBefore='true']">
                    <xsl:value-of select="following-sibling::*[1]"/>
                  </xsl:if>
                </span>
                <span class="g"/>
              </xsl:when>
              <xsl:when test="$nm='listRef'">
                <span class="w listRef">
                  <xsl:if test="preceding-sibling::*[1][self::lit and @noSpaceAfter='true']">
                    <xsl:value-of select="preceding-sibling::*[1]"/>
                  </xsl:if>
                  <xsl:value-of select="."/>
                  <xsl:if test="following-sibling::*[1][self::lit and @noSpaceBefore='true']">
                    <xsl:value-of select="following-sibling::*[1]"/>
                  </xsl:if>
                </span>
                <span class="g"/>
              </xsl:when>
              <xsl:when test="$nm='clauseMkr'">
                <span class="w clauseMkr">
                  <xsl:if test="preceding-sibling::*[1][self::lit and @noSpaceAfter='true']">
                    <xsl:value-of select="preceding-sibling::*[1]"/>
                  </xsl:if>
                  <xsl:value-of select="."/>
                  <xsl:if test="following-sibling::*[1][self::lit and @noSpaceBefore='true']">
                    <xsl:value-of select="following-sibling::*[1]"/>
                  </xsl:if>
                </span>
                <span class="g"/>
              </xsl:when>
              <xsl:when test="$nm='rownum'">
                <span class="w rownum">
                  <xsl:if test="preceding-sibling::*[1][self::lit and @noSpaceAfter='true']">
                    <xsl:value-of select="preceding-sibling::*[1]"/>
                  </xsl:if>
                  <xsl:value-of select="."/>
                  <xsl:if test="following-sibling::*[1][self::lit and @noSpaceBefore='true']">
                    <xsl:value-of select="following-sibling::*[1]"/>
                  </xsl:if>
                </span>
                <span class="g"/>
              </xsl:when>
              <xsl:when test="$nm='note'">
                <span class="w note">
                  <xsl:if test="preceding-sibling::*[1][self::lit and @noSpaceAfter='true']">
                    <xsl:value-of select="preceding-sibling::*[1]"/>
                  </xsl:if>
                  <xsl:value-of select="."/>
                  <xsl:if test="following-sibling::*[1][self::lit and @noSpaceBefore='true']">
                    <xsl:value-of select="following-sibling::*[1]"/>
                  </xsl:if>
                </span>
                <span class="g"/>
              </xsl:when>
              <xsl:otherwise>
                <span class="w">
                  <xsl:if test="preceding-sibling::*[1][self::lit and @noSpaceAfter='true']">
                    <xsl:value-of select="preceding-sibling::*[1]"/>
                  </xsl:if>
                  <xsl:value-of select="."/>
                  <xsl:if test="following-sibling::*[1][self::lit and @noSpaceBefore='true']">
                    <xsl:value-of select="following-sibling::*[1]"/>
                  </xsl:if>
                </span>
                <span class="g"/>
              </xsl:otherwise>
            </xsl:choose>
          </span>
        </xsl:if>
      </xsl:for-each>
    </div>
  </xsl:template>

  <!-- No explicit glosses template; glosses are consumed by interlinear mapping only. -->
</xsl:stylesheet>