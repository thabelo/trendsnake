//+------------------------------------------------------------------+
//|                                             Trailer Seq HA       |
//|                                                          thabelo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Thabelo Mmbengeni"

int BarsCount = 0;

// Global HA Candle Types
int WHITE         = 1;
int RED           = 0;
int CurrentType   = -1;
extern double tp = 300;
extern double sl = 200;

double BSL = 0;//NormalizeDouble(Bid-sl*Point,Digits);
double BTP = NormalizeDouble(Bid+tp*Point, Digits);

double SSL = 0;//NormalizeDouble(Bid+sl*Point,Digits);
double STP = NormalizeDouble(Bid-tp*Point,Digits);

extern string    _______Indicators______;
int       Extra_Pips=10;
extern int        HMA_Period=21;
extern int        HMA_Mode=3;

// trailing stop on / off 
extern bool       trailingStopOn = true;

// Size of buffer to read 
extern int buffer_size = 3;

// number of candles to buy/sell
extern int tradeCount  = 3;

// Magic number
extern int Magic = 2016; 	// Order magic number
// Lots
double LotsOptimized = 1.0;  //Lots

// SLipage to cover low margin brokers
extern  int Slippage = 100;   // in pips

// Cool name
extern string OrderCommentary = "TABS";

// buy/sell state  none=-1, buy=1, sell=0
int state = -1;

// buying / selling trend  buying=1, selling=0
int trend = -1;

// buying / selling trend for buysell EA 
int trendBSA = -1;

// buying
int BUYING = 1;

// selling 
int SELLING = 0;

double prevTrade = 0.0;

// Candle Struct
struct candle {
   double   HABody;        // body length
   double   HAFullBody;    // body length
   double   HALow;         // low proce
   double   HAHigh;        // high price
   double   HAOpen;        // ope price
   double   HAClose;       // close price
   double   HATopTail;     // bullish length
   double   HABottomTail;  // bearish length 
   string   HAColour;      // candle color
   int      HAColourType;  // Red = 0 White =1
   int      HAType;        // Type [0 - 11] (12 Types)
};

// Trading sets 
struct tradeNode {
   int openTypes[];        // Open set
   int countMatch;         // Number of pattern matches
   int type;               // WHITE=1/RED=0
   double percentage;      // probability 
};
 
tradeNode stateNodes[];

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
   return(0);
}
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit() {
   return(0);
}
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
bool setTrailingStop(){
   int ticket = -1;
   bool res = false;
   double stopLoss = 0;
   double offSet = 400;
   printf("Tick value in the deposit currency=%f", OrderProfit());   
   if(state == BUYING ){
      stopLoss = NormalizeDouble(Bid-((MarketInfo(Symbol(),MODE_STOPLEVEL)+offSet)*Point),Digits);
      printf("BUY TS [%f]: %f",Bid, stopLoss);
      // get open ticket number 
      ticket = OrderTicketByMagicNum(Magic);
      if((stopLoss > OrderStopLoss() || OrderStopLoss() == 0) && (OrderProfit() > 0.0) ) 
      {
         res=OrderModify(OrderTicket(),OrderOpenPrice(),stopLoss,0,0,Blue);
         if( !res ){
            Print("Error in OrderModify. Error code=",GetLastError());
            return false;
         } else {
            Print("Order modified successfully.");
            return true;
         }
      }
   }
   else if(state == SELLING ){
      stopLoss = NormalizeDouble(Ask+((MarketInfo(Symbol(),MODE_STOPLEVEL)+offSet)*Point),Digits);
      printf("SELL TS [%f]: %f - %f",Ask, stopLoss,OrderStopLoss());
      ticket = OrderTicketByMagicNum(Magic);
      if((stopLoss < OrderStopLoss() || OrderStopLoss() == 0) && OrderProfit() > 0.0){
         res=OrderModify(OrderTicket(),OrderOpenPrice(),stopLoss,0,0,Blue);
         if( !res ){
            Print("Error in OrderModify. Error code=",GetLastError());
            return false;
         } else {
            Print("Order modified successfully.");
            return true;
         }
      }
   }
   return true;
}
int start() {

   if(trailingStopOn){
      setTrailingStop();
   }
   // get next candle 
   if (BarsCount != Bars) {
      BarsCount = Bars;
   } else {
      return(0);
   }
   
   // TMP Counter
   int tmpCounter          = 0;
   int colorChangeCounter  = 0; 
   int sameColorCounter    = 0; 
   
   // Count HA type matches
   int HACountBuy  = 0;
   int HACountSell = 0;

   bool trendSet = false;
   // control first hit
   bool entrySet = false;
   bool entrySetBSA = false;
   
   // Candle Buffer
   candle HACandlebuffer[];
   ArrayResize(HACandlebuffer, buffer_size+1);

   // skip current candle
   int cnt = 1;
   while ( cnt <= buffer_size) {
      // get candle properties      
      HACandlebuffer[cnt].HAOpen  = iCustom(NULL,0,"Heiken Ashi",Red,White,Red,White,2,cnt);
      HACandlebuffer[cnt].HAClose = iCustom(NULL,0,"Heiken Ashi",Red,White,Red,White,3,cnt);
      
      // Hi Low swap as candle changes direction
      if (HACandlebuffer[cnt].HAClose > HACandlebuffer[cnt].HAOpen) {
         HACandlebuffer[cnt].HALow       = iCustom(NULL,0,"Heiken Ashi",Red,White,Red,White,0,cnt);
         HACandlebuffer[cnt].HAHigh      = iCustom(NULL,0,"Heiken Ashi",Red,White,Red,White,1,cnt);
         // Get Bears and Bulls
         HACandlebuffer[cnt].HATopTail   = MathAbs(HACandlebuffer[cnt].HAHigh - HACandlebuffer[cnt].HAClose);
         HACandlebuffer[cnt].HABottomTail= MathAbs(HACandlebuffer[cnt].HALow  - HACandlebuffer[cnt].HAOpen); 
         CurrentType = WHITE;
         // Define Colour
         HACandlebuffer[cnt].HAColour     = "White";
         HACandlebuffer[cnt].HAColourType = WHITE; 
      } else {
         HACandlebuffer[cnt].HAHigh       = iCustom(NULL,0,"Heiken Ashi",Red,White,Red,White,0,cnt);
         HACandlebuffer[cnt].HALow        = iCustom(NULL,0,"Heiken Ashi",Red,White,Red,White,1,cnt);
         // Get Bears and Bulls
         HACandlebuffer[cnt].HATopTail    = MathAbs(HACandlebuffer[cnt].HAHigh - HACandlebuffer[cnt].HAOpen);
         HACandlebuffer[cnt].HABottomTail = MathAbs(HACandlebuffer[cnt].HALow  - HACandlebuffer[cnt].HAClose); 
         CurrentType = RED;
         // Define Colour
         HACandlebuffer[cnt].HAColour     = "Red";
         HACandlebuffer[cnt].HAColourType = RED; 
      }
      // Candle Body
      HACandlebuffer[cnt].HABody       = MathAbs(HACandlebuffer[cnt].HAOpen - HACandlebuffer[cnt].HAClose);
      HACandlebuffer[cnt].HAFullBody   = MathAbs(HACandlebuffer[cnt].HAHigh - HACandlebuffer[cnt].HALow );

      // Get Candle Type (Depricated - Tabs doesnt like that shit )
      //HACandlebuffer[cnt].HAType = getCandleType(CurrentType, HACandlebuffer[cnt].HABody, HACandlebuffer[cnt].HATopTail, HACandlebuffer[cnt].HABottomTail);

      // Fill data
      //tmpArray[tmpCounter] = HACandlebuffer[cnt].HAColourType;
      
      // Verify Bullish and Bearish    
      if(HACandlebuffer[cnt].HALow > HACandlebuffer[cnt].HAHigh) {
         printf("Error Low is higher than High !!!!!!!!!!!");
      }
     
      // Up down Trend 
      //double trendSellBSA = iCustom(NULL, 0, "Trend/UPDOWN", 3,100,1,cnt);
      //double trendBuyBSA  = iCustom(NULL, 0, "Trend/UPDOWN", 3,100,0,cnt);
     
      // Entry     
      double buyEntry = iCustom(NULL, 0, "Trend/Entry",0, cnt);
      double sellEntry = iCustom(NULL, 0, "Trend/Entry",1, cnt);
      
      // trender
      //double buyTradeAlert = iCustom(NULL, 0, "Trend/buysell20/Buy-Sell_Alerts",1, cnt);
      //double sellTradeAlert = iCustom(NULL, 0, "Trend/buysell20/Buy-Sell_Alerts",0, cnt);
      //printf("[%i] B:[%f]  S:[%f]", cnt, buyTradeAlert, sellTradeAlert);
      //double trendMagic = 2000000000.0000;

      /*if(trendBuy > 0 && trendSet == false){
         trendSet = true;
         trend = BUYING;
      }else if(trendSell >0 && trendSet == false){
         trendSet = true;
         trend = SELLING;
      }
      */
              
      //double buyBlueRedTrend   = iCustom(NULL, 0, "Trend",0, cnt);
      //double sellBlueRedTrend = iCustom(NULL, 0, "Trend",1, cnt);
           
      if( HACandlebuffer[cnt].HAColourType == WHITE && HACountSell < tradeCount){ 
         HACountBuy++;
         HACountSell = 0;
      }
      else if( HACandlebuffer[cnt].HAColourType == RED && HACountBuy < tradeCount){
         HACountSell++;  
         HACountBuy = 0;    
      }
      //printf("[%i/%i] Type: %s [%i][%i]",cnt, buffer_size, HACandlebuffer[cnt].HAColour,HACountBuy, HACountSell);
      if( buyEntry > 0 && entrySet == false ) {
         entrySet = true;
         trend = BUYING;
      }
      else if( sellEntry > 0 && entrySet == false ) {
         entrySet = true;
         trend = SELLING;
      }
      
      /*
      if( trendBuyBSA > 0 && entrySetBSA == false ) {
         trendBSA = BUYING;
         entrySetBSA = true;
      }
      else if( trendSellBSA > 0 && entrySetBSA == false ) {
         trendBSA = SELLING;
         entrySetBSA = true;
      }*/
      cnt++;
   }
   // HMA GOODIES 
   static bool isBuy, isBuy2, isSell, isSell2, isCloseBought, isCloseSold;
   
   double hma0 = iCustom(Symbol(), Period(), "HMA", 40, HMA_Mode, 0, 2, 0);
   double hma1 = iCustom(Symbol(), Period(), "HMA", 40, HMA_Mode, 0, 2, 1);
   double hma2 = iCustom(Symbol(), Period(), "HMA", 40, HMA_Mode, 0, 2, 2);
   
   double hma01 = iCustom(Symbol(), Period(), "HMA", 80, HMA_Mode, 0, 2, 0);
   double hma11 = iCustom(Symbol(), Period(), "HMA", 80, HMA_Mode, 0, 2, 1);
   double hma21 = iCustom(Symbol(), Period(), "HMA", 80, HMA_Mode, 0, 2, 2);
   
   double pipsExtra = Extra_Pips * Point;
   // BUY Ready 
   isBuy  = (hma0 > hma1 && hma1 > hma2);
   isBuy2  = (hma01 > hma11 && hma11 > hma21);

   // SELL Ready
   isSell = (hma0 < hma1 && hma1 < hma2);
   isSell2 = (hma01 < hma11 && hma11 < hma21);
   
   // Close Buy Ready
   isCloseBought = (hma0 < hma1 && hma1 < hma2);
   //isCloseBought = (hma01 < hma11 && hma11 < hma21);
 
   // Close Sell Ready  
   isCloseSold =  (hma0 > hma1 && hma1 > hma2);
   //isCloseSold =  (hma01 > hma11 && hma11 > hma21);

   // Call Buy
   if(isBuy && isBuy2 && state != BUYING){
      CloseOrder(Magic);
      fBuy();
      state = BUYING;   
   }
   // Call Sell
   else if(isSell && isSell2 && state != SELLING){
      CloseOrder(Magic);
      fSell();
      state = SELLING;
   }
   if(OrdersTotal() < 1){
      state = -1;   
   }
   if(state == BUYING && isSell){
      //CloseOrder(Magic);
      //state = -1;
   }else if(state == SELLING && isBuy){
      //CloseOrder(Magic);
      //state = -1;
   }
   /*if(trend == BUYING && entrySet == true ){
      printf("Buy Entry set COUNT: %i", HACountBuy);
   }el   se if(trend == SELLING && entrySet == true ){
      printf("Sell Entry set COUNT: %i", HACountSell);
   }*/
   
   /*
   if( state == SELLING && HACountBuy >= tradeCount ){
      CloseOrder(Magic);
      // reset state
      state = -1;
   } else if(  state == BUYING && HACountSell >= tradeCount ){
      CloseOrder(Magic);
      // reset state
      state = -1;
   }
   if( state != BUYING && HACountBuy == tradeCount && trendBSA == BUYING ){
      ///CloseOrder(Magic);
      fBuy();
      state = BUYING;
   }
   else if( state != SELLING && HACountSell == tradeCount && trendBSA == SELLING ){
      //CloseOrder(Magic);
      fSell();
      state = SELLING;
   }
   if(OrdersTotal() <= 0){
      state = -1;
   }*/
   /*if((entrySet == true && trend == SELLING && state == BUYING) || (HACountSell > 0 && state == BUYING)) {
      CloseOrder(Magic);   
   }else if((entrySet == true && trend == BUYING && state == SELLING) || (HACountBuy > 0 && state == SELLING)) {
      CloseOrder(Magic);
   }*/
   //printf("DONE: [%i][%i]",HACountBuy, HACountSell);
   /*
   if((state == BUYING && trend == SELLING) || (HACountBuy == tradeCount-1 && state == SELLING)){
      CloseOrder(Magic);      
   }
   if((state == SELLING && trend == BUYING) || (HACountSell == tradeCount-1 && state == BUYING)){
      CloseOrder(Magic);
   }

   if( HACountBuy == tradeCount && state != BUYING && trend == BUYING ) {
      CloseOrder(Magic);
      fBuy();
      state = BUYING;
   } else if( HACountSell == tradeCount && state != SELLING && trend == SELLING ){
      CloseOrder(Magic);
      fSell();
      state = SELLING;
   }
   */
   printf("--------- *** ------------");
   return(0);
}
//+------------------------------------------------------------------+
//| Close all open positions matching magic number                                          |
//+------------------------------------------------------------------+
int CloseOrder(int MagicNumber) {
   // Print("Profit for the order 10 : ",OrderProfit());
   bool os,oc = false;
   int total = OrdersTotal();
   printf("Closing....[%i]", total);
   for (int i = 0; i < total; i++) {
      os = OrderSelect(i, SELECT_BY_POS);
      printf("Iterate.............: %i", OrderMagicNumber());
      // if (OrderSelect(i, SELECT_BY_POS) == false) continue;
      if (OrderMagicNumber() == MagicNumber){
         if (OrderType() == OP_BUY)
         {
            printf("Closing Buy++++++++++++++++++++++++++++++++++++++++++");
            RefreshRates();
            oc = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage);
         }
         else if (OrderType() == OP_SELL){
            printf("Closing Sell------------------------------------------");
            RefreshRates();
            oc = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage);
         }
      }
   }
   return(0);
}

//+------------------------------------------------------------------+
//| Buy                                                              |
//+------------------------------------------------------------------+
void fBuy() {
	RefreshRates();
	int result = -1;
	/*
	Print("Symbol : ", Symbol());
	Print("OP_BUY", OP_BUY);
	Print("Lots :", LotsOptimized());
	Print("Slipage :", Slippage);
   */
	result = OrderSend(Symbol(), OP_BUY, LotsOptimized, Ask, Slippage, BSL, BTP,OrderCommentary, Magic);

	if (result == -1) {
		int e = GetLastError();
		Print("OrderSend Error: ", e);
	}
}

//+------------------------------------------------------------------+
//| Sell                                                             |
//+------------------------------------------------------------------+
void fSell() {
	RefreshRates();
	int result = -1;
	result = OrderSend(Symbol(), OP_SELL, LotsOptimized, Bid, Slippage,SSL,STP, OrderCommentary, Magic);
	if (result == -1)
	{
		int e = GetLastError();
		Print("OrderSend Error: ", e);
	}
}
//+------------------------------------------------------------------+
//| Get order ticket by magic number                                 |
//+------------------------------------------------------------------+
int OrderTicketByMagicNum(int magic_number) {
  for(int i=0;i<OrdersTotal();i++)
  {
    if (OrderSelect(i, SELECT_BY_POS) == false) continue;
    if (OrderMagicNumber() == magic_number) return(OrderTicket());
  }   
  return -1;
}