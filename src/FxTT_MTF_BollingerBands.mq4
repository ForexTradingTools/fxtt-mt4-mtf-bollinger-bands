//+------------------------------------------------------------------+
//| FxTT_MTF_BollingerBands.mq4                                      |
//| Multi-timeframe Bollinger Bands panel for MetaTrader 4           |
//+------------------------------------------------------------------+
#property strict
#property copyright "FxTT"
#property link      "https://forextradingtools.eu/en/marketplace/mtf-bollinger-bands"
#property version   "1.00"
#property description "Bollinger Bands Multi-Timeframe Panel"
#property indicator_chart_window
#property indicator_buffers 27

#define TF_COUNT 9
#define TF_MN1 0
#define TF_W1  1
#define TF_D1  2
#define TF_H4  3
#define TF_H1  4
#define TF_M30 5
#define TF_M15 6
#define TF_M5  7
#define TF_M1  8

//--- Bollinger Bands
input int    InpPeriod          = 20;   // Period
input double InpDeviations      = 2.0;  // Deviations
input int    InpBBShift         = 0;    // Shift
//--- Panel
input int    InpPanelX          = 20;   // Panel X (pixels from corner)
input int    InpPanelY          = 30;   // Panel Y (pixels from corner)
//--- Band labels
input bool   InpShowBandLabels  = true; // Show right-side band labels
input int    InpLabelShiftBars  = 1;    // Label shift to the right (bars)
input int    InpLabelFontSize   = 8;    // Label font size

//--- Indicator buffers: upper, middle, lower for MN1 through M1
double g_MN1Upper[], g_MN1Middle[], g_MN1Lower[];
double g_W1Upper[],  g_W1Middle[],  g_W1Lower[];
double g_D1Upper[],  g_D1Middle[],  g_D1Lower[];
double g_H4Upper[],  g_H4Middle[],  g_H4Lower[];
double g_H1Upper[],  g_H1Middle[],  g_H1Lower[];
double g_M30Upper[], g_M30Middle[], g_M30Lower[];
double g_M15Upper[], g_M15Middle[], g_M15Lower[];
double g_M5Upper[],  g_M5Middle[],  g_M5Lower[];
double g_M1Upper[],  g_M1Middle[],  g_M1Lower[];

//--- Timeframe metadata
int    TF_PERIODS[TF_COUNT];
color  TF_COLORS[TF_COUNT];
string TF_LABELS[TF_COUNT];
string TF_CB_IDS[TF_COUNT];
string TF_GV_KEYS[TF_COUNT];

bool     g_Show[TF_COUNT];
bool     g_Eligible[TF_COUNT];
bool     g_PrevEffective[TF_COUNT];
datetime g_LastTFTime[TF_COUNT];
datetime g_LastBarTime = 0;
datetime g_Time[];
int      g_RatesTotal = 0;
string   g_Pfx;
int      g_PanelX = 0;
int      g_PanelY = 0;
bool     g_Expanded = true;

//--- Drag state
bool g_Dragging = false;
bool g_ActuallyDragged = false;
bool g_WasLBDown = false;
int  g_DragOffX = 0;
int  g_DragOffY = 0;
int  g_DragStartX = 0;
int  g_DragStartY = 0;

const int DRAG_THRESHOLD = 4;
const int PANEL_W = 215;
const int TOGGLE_H = 24;
const int CHECK_H = 22;
const int PADDING = 4;
const int GAP = 2;
const color CLR_PANEL_BG = C'18,26,42';
const color CLR_PANEL_BORDER = C'55,85,130';
const color CLR_TOGGLE_BG = C'35,55,90';
const color CLR_CHECK_BG_ON = C'28,44,68';
const color CLR_CHECK_BG_OFF = C'16,22,34';
const color CLR_UNCHECKED_TEXT = C'70,85,100';
const color CLR_DISABLED_BG = C'14,18,24';
const color CLR_DISABLED_TEXT = C'40,48,58';

string N(string name) { return g_Pfx + name; }
string GVK(string suffix) { return "BBMTF_" + IntegerToString(ChartID()) + "_" + suffix; }
int PlotBase(int tfIndex) { return tfIndex * 3; }
int PanelHeight(bool expanded)
{
   if(expanded)
      return PADDING + TOGGLE_H + GAP + TF_COUNT * (CHECK_H + GAP) + PADDING;
   return PADDING + TOGGLE_H + PADDING;
}

void InitMetadata()
{
   TF_PERIODS[TF_MN1] = PERIOD_MN1; TF_COLORS[TF_MN1] = clrMagenta;     TF_LABELS[TF_MN1] = "MN1"; TF_CB_IDS[TF_MN1] = "CbMN1"; TF_GV_KEYS[TF_MN1] = "ShowMN1";
   TF_PERIODS[TF_W1]  = PERIOD_W1;  TF_COLORS[TF_W1]  = clrDodgerBlue;  TF_LABELS[TF_W1]  = "W1";  TF_CB_IDS[TF_W1]  = "CbW1";  TF_GV_KEYS[TF_W1]  = "ShowW1";
   TF_PERIODS[TF_D1]  = PERIOD_D1;  TF_COLORS[TF_D1]  = clrOrange;      TF_LABELS[TF_D1]  = "D1";  TF_CB_IDS[TF_D1]  = "CbD1";  TF_GV_KEYS[TF_D1]  = "ShowD1";
   TF_PERIODS[TF_H4]  = PERIOD_H4;  TF_COLORS[TF_H4]  = clrLimeGreen;   TF_LABELS[TF_H4]  = "H4";  TF_CB_IDS[TF_H4]  = "CbH4";  TF_GV_KEYS[TF_H4]  = "ShowH4";
   TF_PERIODS[TF_H1]  = PERIOD_H1;  TF_COLORS[TF_H1]  = clrGold;        TF_LABELS[TF_H1]  = "H1";  TF_CB_IDS[TF_H1]  = "CbH1";  TF_GV_KEYS[TF_H1]  = "ShowH1";
   TF_PERIODS[TF_M30] = PERIOD_M30; TF_COLORS[TF_M30] = clrTomato;       TF_LABELS[TF_M30] = "M30"; TF_CB_IDS[TF_M30] = "CbM30"; TF_GV_KEYS[TF_M30] = "ShowM30";
   TF_PERIODS[TF_M15] = PERIOD_M15; TF_COLORS[TF_M15] = clrDeepSkyBlue;  TF_LABELS[TF_M15] = "M15"; TF_CB_IDS[TF_M15] = "CbM15"; TF_GV_KEYS[TF_M15] = "ShowM15";
   TF_PERIODS[TF_M5]  = PERIOD_M5;  TF_COLORS[TF_M5]  = clrViolet;       TF_LABELS[TF_M5]  = "M5";  TF_CB_IDS[TF_M5]  = "CbM5";  TF_GV_KEYS[TF_M5]  = "ShowM5";
   TF_PERIODS[TF_M1]  = PERIOD_M1;  TF_COLORS[TF_M1]  = clrSilver;       TF_LABELS[TF_M1]  = "M1";  TF_CB_IDS[TF_M1]  = "CbM1";  TF_GV_KEYS[TF_M1]  = "ShowM1";
}

void SetAllSeries(double &a[], double &b[], double &c[])
{
   ArraySetAsSeries(a, true);
   ArraySetAsSeries(b, true);
   ArraySetAsSeries(c, true);
}

void RegisterBuffers()
{
   SetIndexBuffer(0, g_MN1Upper); SetIndexBuffer(1, g_MN1Middle); SetIndexBuffer(2, g_MN1Lower);
   SetIndexBuffer(3, g_W1Upper);  SetIndexBuffer(4, g_W1Middle);  SetIndexBuffer(5, g_W1Lower);
   SetIndexBuffer(6, g_D1Upper);  SetIndexBuffer(7, g_D1Middle);  SetIndexBuffer(8, g_D1Lower);
   SetIndexBuffer(9, g_H4Upper);  SetIndexBuffer(10, g_H4Middle); SetIndexBuffer(11, g_H4Lower);
   SetIndexBuffer(12, g_H1Upper); SetIndexBuffer(13, g_H1Middle); SetIndexBuffer(14, g_H1Lower);
   SetIndexBuffer(15, g_M30Upper); SetIndexBuffer(16, g_M30Middle); SetIndexBuffer(17, g_M30Lower);
   SetIndexBuffer(18, g_M15Upper); SetIndexBuffer(19, g_M15Middle); SetIndexBuffer(20, g_M15Lower);
   SetIndexBuffer(21, g_M5Upper); SetIndexBuffer(22, g_M5Middle); SetIndexBuffer(23, g_M5Lower);
   SetIndexBuffer(24, g_M1Upper); SetIndexBuffer(25, g_M1Middle); SetIndexBuffer(26, g_M1Lower);

   SetAllSeries(g_MN1Upper, g_MN1Middle, g_MN1Lower);
   SetAllSeries(g_W1Upper, g_W1Middle, g_W1Lower);
   SetAllSeries(g_D1Upper, g_D1Middle, g_D1Lower);
   SetAllSeries(g_H4Upper, g_H4Middle, g_H4Lower);
   SetAllSeries(g_H1Upper, g_H1Middle, g_H1Lower);
   SetAllSeries(g_M30Upper, g_M30Middle, g_M30Lower);
   SetAllSeries(g_M15Upper, g_M15Middle, g_M15Lower);
   SetAllSeries(g_M5Upper, g_M5Middle, g_M5Lower);
   SetAllSeries(g_M1Upper, g_M1Middle, g_M1Lower);
}

void ConfigurePlot(int index, string label, color clr, int style)
{
   SetIndexStyle(index, DRAW_LINE, style, 1, clr);
   SetIndexLabel(index, label);
   SetIndexEmptyValue(index, EMPTY_VALUE);
   SetIndexDrawBegin(index, InpPeriod);
}

void ConfigurePlots()
{
   ConfigurePlot(0, "BB MN1 Upper", clrMagenta, STYLE_DASH); ConfigurePlot(1, "BB MN1 Middle", clrMagenta, STYLE_SOLID); ConfigurePlot(2, "BB MN1 Lower", clrMagenta, STYLE_DASH);
   ConfigurePlot(3, "BB W1 Upper", clrDodgerBlue, STYLE_DASH); ConfigurePlot(4, "BB W1 Middle", clrDodgerBlue, STYLE_SOLID); ConfigurePlot(5, "BB W1 Lower", clrDodgerBlue, STYLE_DASH);
   ConfigurePlot(6, "BB D1 Upper", clrOrange, STYLE_DASH); ConfigurePlot(7, "BB D1 Middle", clrOrange, STYLE_SOLID); ConfigurePlot(8, "BB D1 Lower", clrOrange, STYLE_DASH);
   ConfigurePlot(9, "BB H4 Upper", clrLimeGreen, STYLE_DASH); ConfigurePlot(10, "BB H4 Middle", clrLimeGreen, STYLE_SOLID); ConfigurePlot(11, "BB H4 Lower", clrLimeGreen, STYLE_DASH);
   ConfigurePlot(12, "BB H1 Upper", clrGold, STYLE_DASH); ConfigurePlot(13, "BB H1 Middle", clrGold, STYLE_SOLID); ConfigurePlot(14, "BB H1 Lower", clrGold, STYLE_DASH);
   ConfigurePlot(15, "BB M30 Upper", clrTomato, STYLE_DASH); ConfigurePlot(16, "BB M30 Middle", clrTomato, STYLE_SOLID); ConfigurePlot(17, "BB M30 Lower", clrTomato, STYLE_DASH);
   ConfigurePlot(18, "BB M15 Upper", clrDeepSkyBlue, STYLE_DASH); ConfigurePlot(19, "BB M15 Middle", clrDeepSkyBlue, STYLE_SOLID); ConfigurePlot(20, "BB M15 Lower", clrDeepSkyBlue, STYLE_DASH);
   ConfigurePlot(21, "BB M5 Upper", clrViolet, STYLE_DASH); ConfigurePlot(22, "BB M5 Middle", clrViolet, STYLE_SOLID); ConfigurePlot(23, "BB M5 Lower", clrViolet, STYLE_DASH);
   ConfigurePlot(24, "BB M1 Upper", clrSilver, STYLE_DASH); ConfigurePlot(25, "BB M1 Middle", clrSilver, STYLE_SOLID); ConfigurePlot(26, "BB M1 Lower", clrSilver, STYLE_DASH);
}

void SetPlotVisibility(int plotBase, bool show)
{
   for(int j = 0; j < 3; j++)
      SetIndexStyle(plotBase + j, show ? DRAW_LINE : DRAW_NONE);
}

void StateSave()
{
   GlobalVariableSet(GVK("X"), g_PanelX);
   GlobalVariableSet(GVK("Y"), g_PanelY);
   GlobalVariableSet(GVK("Expanded"), g_Expanded ? 1.0 : 0.0);
   for(int i = 0; i < TF_COUNT; i++)
      GlobalVariableSet(GVK(TF_GV_KEYS[i]), g_Show[i] ? 1.0 : 0.0);
}

bool StateLoad()
{
   if(!GlobalVariableCheck(GVK("X")))
      return false;
   g_PanelX = (int)GlobalVariableGet(GVK("X"));
   g_PanelY = (int)GlobalVariableGet(GVK("Y"));
   g_Expanded = GlobalVariableGet(GVK("Expanded")) != 0.0;
   for(int i = 0; i < TF_COUNT; i++)
      if(GlobalVariableCheck(GVK(TF_GV_KEYS[i])))
         g_Show[i] = GlobalVariableGet(GVK(TF_GV_KEYS[i])) != 0.0;
   return true;
}

void StateDelete()
{
   GlobalVariableDel(GVK("X"));
   GlobalVariableDel(GVK("Y"));
   GlobalVariableDel(GVK("Expanded"));
   for(int i = 0; i < TF_COUNT; i++)
      GlobalVariableDel(GVK(TF_GV_KEYS[i]));
}

void CreateBackground(string name, int x, int y, int w, int h)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, CLR_PANEL_BG);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, CLR_PANEL_BORDER);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
}

void CreateButton(string name, int x, int y, int w, int h, string text, color bg, color clr, bool state)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, CLR_PANEL_BORDER);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, name, OBJPROP_FONT, "Segoe UI");
   ObjectSetInteger(0, name, OBJPROP_STATE, state);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 10);
}

void UpdateCheckbox(string id, bool checked, color accent)
{
   ObjectSetInteger(0, N(id), OBJPROP_STATE, checked);
   ObjectSetInteger(0, N(id), OBJPROP_BGCOLOR, checked ? CLR_CHECK_BG_ON : CLR_CHECK_BG_OFF);
   ObjectSetInteger(0, N(id), OBJPROP_COLOR, checked ? accent : CLR_UNCHECKED_TEXT);
}

void DeleteBandLabel(int plotIndex)
{
   ObjectDelete(0, N("BandLabel_" + IntegerToString(plotIndex)));
}

void DeleteBandLabels()
{
   for(int i = 0; i < TF_COUNT * 3; i++)
      DeleteBandLabel(i);
}

string BandName(int offset)
{
   if(offset == 0) return "Upper";
   if(offset == 1) return "Middle";
   return "Lower";
}

void SetBandLabel(int plotIndex, bool visible, datetime baseTime, double price, int barSeconds)
{
   if(!InpShowBandLabels || !visible || price == EMPTY_VALUE || !MathIsValidNumber(price))
   {
      DeleteBandLabel(plotIndex);
      return;
   }
   string name = N("BandLabel_" + IntegerToString(plotIndex));
   datetime labelTime = baseTime + (datetime)MathMax(0, InpLabelShiftBars) * barSeconds;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, labelTime, price);
   else
      ObjectMove(0, name, 0, labelTime, price);
   ObjectSetString(0, name, OBJPROP_TEXT, "BB " + TF_LABELS[plotIndex / 3] + " " + BandName(plotIndex % 3));
   ObjectSetInteger(0, name, OBJPROP_COLOR, TF_COLORS[plotIndex / 3]);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, MathMax(1, InpLabelFontSize));
   ObjectSetString(0, name, OBJPROP_FONT, "Segoe UI");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

void RefreshLabelsForTF(int tfIndex, bool visible, datetime baseTime, int barSeconds,
                        double &upper[], double &middle[], double &lower[])
{
   int base = PlotBase(tfIndex);
   if(!visible || g_RatesTotal <= 0)
   {
      DeleteBandLabel(base); DeleteBandLabel(base + 1); DeleteBandLabel(base + 2);
      return;
   }
   SetBandLabel(base, true, baseTime, upper[0], barSeconds);
   SetBandLabel(base + 1, true, baseTime, middle[0], barSeconds);
   SetBandLabel(base + 2, true, baseTime, lower[0], barSeconds);
}

void RefreshLabels()
{
   if(!InpShowBandLabels || g_RatesTotal <= 0 || ArraySize(g_Time) <= 0)
   {
      DeleteBandLabels();
      return;
   }
   int seconds = PeriodSeconds(Period());
   if(seconds <= 0) seconds = 60;
   datetime baseTime = g_Time[0];
   RefreshLabelsForTF(TF_MN1, g_Show[TF_MN1] && g_Eligible[TF_MN1], baseTime, seconds, g_MN1Upper, g_MN1Middle, g_MN1Lower);
   RefreshLabelsForTF(TF_W1, g_Show[TF_W1] && g_Eligible[TF_W1], baseTime, seconds, g_W1Upper, g_W1Middle, g_W1Lower);
   RefreshLabelsForTF(TF_D1, g_Show[TF_D1] && g_Eligible[TF_D1], baseTime, seconds, g_D1Upper, g_D1Middle, g_D1Lower);
   RefreshLabelsForTF(TF_H4, g_Show[TF_H4] && g_Eligible[TF_H4], baseTime, seconds, g_H4Upper, g_H4Middle, g_H4Lower);
   RefreshLabelsForTF(TF_H1, g_Show[TF_H1] && g_Eligible[TF_H1], baseTime, seconds, g_H1Upper, g_H1Middle, g_H1Lower);
   RefreshLabelsForTF(TF_M30, g_Show[TF_M30] && g_Eligible[TF_M30], baseTime, seconds, g_M30Upper, g_M30Middle, g_M30Lower);
   RefreshLabelsForTF(TF_M15, g_Show[TF_M15] && g_Eligible[TF_M15], baseTime, seconds, g_M15Upper, g_M15Middle, g_M15Lower);
   RefreshLabelsForTF(TF_M5, g_Show[TF_M5] && g_Eligible[TF_M5], baseTime, seconds, g_M5Upper, g_M5Middle, g_M5Lower);
   RefreshLabelsForTF(TF_M1, g_Show[TF_M1] && g_Eligible[TF_M1], baseTime, seconds, g_M1Upper, g_M1Middle, g_M1Lower);
}

void CreatePanel()
{
   int x = g_PanelX;
   int y = g_PanelY;
   int bx = x + PADDING;
   int bw = PANEL_W - 2 * PADDING;
   CreateBackground(N("BG"), x, y, PANEL_W, PanelHeight(g_Expanded));
   CreateButton(N("Toggle"), bx, y + PADDING, bw, TOGGLE_H,
                g_Expanded ? " BB Panel  ^" : " BB Panel  v", CLR_TOGGLE_BG, clrWhite, false);
   int cy = y + PADDING + TOGGLE_H + GAP;
   for(int i = 0; i < TF_COUNT; i++)
   {
      bool show = g_Show[i] && g_Eligible[i];
      color fg = !g_Eligible[i] ? CLR_DISABLED_TEXT : (show ? TF_COLORS[i] : CLR_UNCHECKED_TEXT);
      color bg = !g_Eligible[i] ? CLR_DISABLED_BG : (show ? CLR_CHECK_BG_ON : CLR_CHECK_BG_OFF);
      CreateButton(N(TF_CB_IDS[i]), bx, cy, bw, CHECK_H,
                   "■  Bollinger Bands " + TF_LABELS[i], bg, fg, show);
      ObjectSetInteger(0, N(TF_CB_IDS[i]), OBJPROP_TIMEFRAMES, g_Expanded ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
      cy += CHECK_H + GAP;
      SetPlotVisibility(PlotBase(i), show);
   }
   RefreshLabels();
   ChartRedraw(0);
}

void DeletePanel()
{
   ObjectDelete(0, N("BG"));
   ObjectDelete(0, N("Toggle"));
   for(int i = 0; i < TF_COUNT; i++)
      ObjectDelete(0, N(TF_CB_IDS[i]));
   DeleteBandLabels();
}

void MovePanel(int x, int y)
{
   g_PanelX = x;
   g_PanelY = y;
   ObjectSetInteger(0, N("BG"), OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, N("BG"), OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, N("Toggle"), OBJPROP_XDISTANCE, x + PADDING);
   ObjectSetInteger(0, N("Toggle"), OBJPROP_YDISTANCE, y + PADDING);
   int cy = y + PADDING + TOGGLE_H + GAP;
   for(int i = 0; i < TF_COUNT; i++)
   {
      ObjectSetInteger(0, N(TF_CB_IDS[i]), OBJPROP_XDISTANCE, x + PADDING);
      ObjectSetInteger(0, N(TF_CB_IDS[i]), OBJPROP_YDISTANCE, cy);
      cy += CHECK_H + GAP;
   }
   StateSave();
   ChartRedraw(0);
}

void SetPanelExpanded(bool expand)
{
   g_Expanded = expand;
   ObjectSetInteger(0, N("BG"), OBJPROP_YSIZE, PanelHeight(expand));
   ObjectSetInteger(0, N("Toggle"), OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetString(0, N("Toggle"), OBJPROP_TEXT, expand ? " BB Panel  ^" : " BB Panel  v");
   for(int i = 0; i < TF_COUNT; i++)
      ObjectSetInteger(0, N(TF_CB_IDS[i]), OBJPROP_TIMEFRAMES, expand ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
   StateSave();
   ChartRedraw(0);
}

void FillBands(int tfIndex, int start, int total)
{
   if(start >= total || iBars(Symbol(), TF_PERIODS[tfIndex]) < InpPeriod)
      return;
   for(int shift = start; shift < total; shift++)
   {
      int htfShift = iBarShift(Symbol(), TF_PERIODS[tfIndex], g_Time[shift], false);
      double upperValue = EMPTY_VALUE;
      double middleValue = EMPTY_VALUE;
      double lowerValue = EMPTY_VALUE;
      if(htfShift >= 0)
      {
         upperValue = iBands(Symbol(), TF_PERIODS[tfIndex], InpPeriod, InpDeviations, InpBBShift, PRICE_CLOSE, MODE_UPPER, htfShift);
         middleValue = iBands(Symbol(), TF_PERIODS[tfIndex], InpPeriod, InpDeviations, InpBBShift, PRICE_CLOSE, MODE_MAIN, htfShift);
         lowerValue = iBands(Symbol(), TF_PERIODS[tfIndex], InpPeriod, InpDeviations, InpBBShift, PRICE_CLOSE, MODE_LOWER, htfShift);
      }
      switch(tfIndex)
      {
         case TF_MN1: g_MN1Upper[shift] = upperValue; g_MN1Middle[shift] = middleValue; g_MN1Lower[shift] = lowerValue; break;
         case TF_W1:  g_W1Upper[shift] = upperValue;  g_W1Middle[shift] = middleValue;  g_W1Lower[shift] = lowerValue;  break;
         case TF_D1:  g_D1Upper[shift] = upperValue;  g_D1Middle[shift] = middleValue;  g_D1Lower[shift] = lowerValue;  break;
         case TF_H4:  g_H4Upper[shift] = upperValue;  g_H4Middle[shift] = middleValue;  g_H4Lower[shift] = lowerValue;  break;
         case TF_H1:  g_H1Upper[shift] = upperValue;  g_H1Middle[shift] = middleValue;  g_H1Lower[shift] = lowerValue;  break;
         case TF_M30: g_M30Upper[shift] = upperValue; g_M30Middle[shift] = middleValue; g_M30Lower[shift] = lowerValue; break;
         case TF_M15: g_M15Upper[shift] = upperValue; g_M15Middle[shift] = middleValue; g_M15Lower[shift] = lowerValue; break;
         case TF_M5:  g_M5Upper[shift] = upperValue;  g_M5Middle[shift] = middleValue;  g_M5Lower[shift] = lowerValue;  break;
         case TF_M1:  g_M1Upper[shift] = upperValue;  g_M1Middle[shift] = middleValue;  g_M1Lower[shift] = lowerValue;  break;
      }
   }
}

void ClearBands(int tfIndex)
{
   switch(tfIndex)
   {
      case TF_MN1: ArrayInitialize(g_MN1Upper, EMPTY_VALUE); ArrayInitialize(g_MN1Middle, EMPTY_VALUE); ArrayInitialize(g_MN1Lower, EMPTY_VALUE); break;
      case TF_W1:  ArrayInitialize(g_W1Upper, EMPTY_VALUE);  ArrayInitialize(g_W1Middle, EMPTY_VALUE);  ArrayInitialize(g_W1Lower, EMPTY_VALUE);  break;
      case TF_D1:  ArrayInitialize(g_D1Upper, EMPTY_VALUE);  ArrayInitialize(g_D1Middle, EMPTY_VALUE);  ArrayInitialize(g_D1Lower, EMPTY_VALUE);  break;
      case TF_H4:  ArrayInitialize(g_H4Upper, EMPTY_VALUE);  ArrayInitialize(g_H4Middle, EMPTY_VALUE);  ArrayInitialize(g_H4Lower, EMPTY_VALUE);  break;
      case TF_H1:  ArrayInitialize(g_H1Upper, EMPTY_VALUE);  ArrayInitialize(g_H1Middle, EMPTY_VALUE);  ArrayInitialize(g_H1Lower, EMPTY_VALUE);  break;
      case TF_M30: ArrayInitialize(g_M30Upper, EMPTY_VALUE); ArrayInitialize(g_M30Middle, EMPTY_VALUE); ArrayInitialize(g_M30Lower, EMPTY_VALUE); break;
      case TF_M15: ArrayInitialize(g_M15Upper, EMPTY_VALUE); ArrayInitialize(g_M15Middle, EMPTY_VALUE); ArrayInitialize(g_M15Lower, EMPTY_VALUE); break;
      case TF_M5:  ArrayInitialize(g_M5Upper, EMPTY_VALUE);  ArrayInitialize(g_M5Middle, EMPTY_VALUE);  ArrayInitialize(g_M5Lower, EMPTY_VALUE);  break;
      case TF_M1:  ArrayInitialize(g_M1Upper, EMPTY_VALUE);  ArrayInitialize(g_M1Middle, EMPTY_VALUE);  ArrayInitialize(g_M1Lower, EMPTY_VALUE);  break;
   }
}

void ToggleBand(int tfIndex)
{
   if(!g_Eligible[tfIndex])
   {
      ObjectSetInteger(0, N(TF_CB_IDS[tfIndex]), OBJPROP_STATE, false);
      return;
   }
   g_Show[tfIndex] = ObjectGetInteger(0, N(TF_CB_IDS[tfIndex]), OBJPROP_STATE) != 0;
   UpdateCheckbox(TF_CB_IDS[tfIndex], g_Show[tfIndex], TF_COLORS[tfIndex]);
   SetPlotVisibility(PlotBase(tfIndex), g_Show[tfIndex]);
   if(g_Show[tfIndex])
      FillBands(tfIndex, 0, g_RatesTotal);
   else
      ClearBands(tfIndex);
   g_PrevEffective[tfIndex] = g_Show[tfIndex];
   RefreshLabels();
   StateSave();
   ChartRedraw(0);
}

int OnInit()
{
   if(InpPeriod < 1 || InpDeviations <= 0.0)
      return INIT_PARAMETERS_INCORRECT;
   InitMetadata();
   g_Pfx = "BBMTF_" + IntegerToString(ChartID()) + "_";
   ArrayInitialize(g_Show, true);
   ArrayInitialize(g_PrevEffective, false);
   ArrayInitialize(g_LastTFTime, 0);
   if(!StateLoad())
   {
      g_PanelX = MathMax(0, InpPanelX);
      g_PanelY = MathMax(0, InpPanelY);
   }
   for(int i = 0; i < TF_COUNT; i++)
      g_Eligible[i] = Period() <= TF_PERIODS[i];
   RegisterBuffers();
   ConfigurePlots();
   IndicatorShortName(StringFormat("BB MTF (%d, %.1f)", InpPeriod, InpDeviations));
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   CreatePanel();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
   DeletePanel();
   if(reason == REASON_REMOVE || reason == REASON_RECOMPILE)
      StateDelete();
   ChartRedraw(0);
}

int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[], const double &high[],
                const double &low[], const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
   g_RatesTotal = rates_total;
   ArrayCopy(g_Time, time);
   ArraySetAsSeries(g_Time, true);
   if(rates_total < InpPeriod)
      return 0;

   bool newCurrentBar = (g_Time[0] != g_LastBarTime);
   bool anyChange = newCurrentBar || prev_calculated == 0;
   for(int i = 0; i < TF_COUNT; i++)
   {
      datetime tfTime = iTime(Symbol(), TF_PERIODS[i], 0);
      if(tfTime != g_LastTFTime[i]) anyChange = true;
      if(g_Show[i] != g_PrevEffective[i]) anyChange = true;
   }
   if(prev_calculated > 0 && !anyChange)
      return rates_total;

   int start = prev_calculated == 0 ? 0 : MathMax(0, prev_calculated - 2);
   for(int i = 0; i < TF_COUNT; i++)
   {
      bool effective = g_Show[i] && g_Eligible[i];
      if(effective)
         FillBands(i, start, rates_total);
      else if(prev_calculated == 0 || g_PrevEffective[i])
         ClearBands(i);
      g_LastTFTime[i] = iTime(Symbol(), TF_PERIODS[i], 0);
      g_PrevEffective[i] = g_Show[i];
   }
   g_LastBarTime = g_Time[0];
   RefreshLabels();
   return rates_total;
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      int mouseX = (int)lparam;
      int mouseY = (int)dparam;
      bool leftDown = (StringToInteger(sparam) & 1) != 0;
      if(leftDown && !g_WasLBDown)
      {
         bool overTitle = mouseX >= g_PanelX + PADDING && mouseX <= g_PanelX + PANEL_W - PADDING &&
                          mouseY >= g_PanelY + PADDING && mouseY <= g_PanelY + PADDING + TOGGLE_H;
         if(overTitle)
         {
            g_Dragging = true;
            g_ActuallyDragged = false;
            g_DragOffX = mouseX - g_PanelX;
            g_DragOffY = mouseY - g_PanelY;
            g_DragStartX = mouseX;
            g_DragStartY = mouseY;
            ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
         }
      }
      if(!leftDown && g_Dragging)
      {
         g_Dragging = false;
         ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
      }
      if(g_Dragging && leftDown)
      {
         int dx = mouseX - g_DragStartX;
         int dy = mouseY - g_DragStartY;
         if(!g_ActuallyDragged && (MathAbs(dx) > DRAG_THRESHOLD || MathAbs(dy) > DRAG_THRESHOLD))
            g_ActuallyDragged = true;
         if(g_ActuallyDragged)
            MovePanel(mouseX - g_DragOffX, mouseY - g_DragOffY);
      }
      g_WasLBDown = leftDown;
      return;
   }
   if(id != CHARTEVENT_OBJECT_CLICK)
      return;
   if(sparam == N("Toggle"))
   {
      ObjectSetInteger(0, N("Toggle"), OBJPROP_STATE, false);
      if(g_ActuallyDragged) { g_ActuallyDragged = false; return; }
      SetPanelExpanded(!g_Expanded);
      return;
   }
   for(int i = 0; i < TF_COUNT; i++)
      if(sparam == N(TF_CB_IDS[i]))
      {
         ToggleBand(i);
         return;
      }
}
//+------------------------------------------------------------------+
