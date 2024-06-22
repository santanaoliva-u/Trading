//                                                    RB_OIL_KD_V0.1.mq4
//+-------------------------------------------------------------------+
//|                                          Sistemas Inversores      |
//|                                 http://www.sistemasinversores.com |
//|                                                                   |
//|Copyright (c) 2011, Sistemas Inversores                            |
//|All rights reserved.                                               |
//|                                                                   |
//|Redistribution and use in source and binary forms, with or without |
//|modification, are permitted provided that the following conditions !
//|are met:                                                           |
//|                                                                   |  
//|Redistributions of source code must retain the above copyright     |
//|  notice, this list of conditions and the following disclaimer.    |
//|Redistributions in binary form must reproduce the above copyright  |
//|  notice, this list of conditions and the following disclaimer in  |
//|  the documentation and/or other materials provided with the       |
//|  distribution.                                                    |
//|                                                                   |     
//|THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS|
//|"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT  |
//|LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS  |
//|FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE     |
//|COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,         |
//|INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES |
//|(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR |
//|SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) |
//|HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,|
//|STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)      |
//|ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED|
//| OF THE POSSIBILITY OF SUCH DAMAGE.                                |
//+-------------------------------------------------------------------+
#property copyright "Copyright 2023, ALPHADVISOR.COM"
#property link      "https://alphadvisor.com"
#property version   "3.0.1"

// Globales
string NombreDelEA = "RB_OIL_KD_V0.1";
string VersionEA = "v1.0";
extern double MaxSpreadTolerable = 3.0; //Maximo Spread
extern int Slippage = 1;
extern int MagicNumber = 0;
int MyPoint=1;
int TiposDeOrden[1];
bool allowDemo = true;
bool allowTesting = true;
bool allowOptimization = true;
int accountId = 0;
string caducity = "";
bool bAllowStrategy=true;
static datetime last = Time[0];
int DDPips=0;

long contA=0;
long contB=0;
long contI=0;

enum CritOptimizacionEnum{
   sin_valor = 0,
   criterio_br = 1,
   criterio_sqn = 2,
   criterio_kratio = 3
};

input CritOptimizacionEnum custom = criterio_sqn;


extern int DDStop = 0;
extern int VALOR_ADX_ENTRADA = 10;
extern int DIAS_CLOSE_COMPRA = 0;
extern int DIAS_CLOSE_VENTA = 0;
extern int period_ADX = 14;
extern int StopLoss_BUY_1 = 0;
extern int StopLoss_SELL_1 = 0;
extern double Lote_SELL_1 = 0.1;
extern double Lote_BUY_1 = 0.1;
extern double RATIO_SL_TP = 0.0;
extern int TakeProfit_BUY_1 = 0;
extern int TakeProfit_SELL_1 = 0;




#include <stdlibSIv2.03.mqh>

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//----

    

   if(MagicNumber==0 && !IsTesting()){
      ExpertRemove();
      Print("Introduzca un MagicNumber ?nico para identificar el EA.");
      Alert("Introduzca un MagicNumber ?nico para identificar el EA.");
      return (INIT_FAILED);
   }

// D?gitos para brokers con pips fraccionarios.  
   if(Digits==3||Digits==5)MyPoint=10; else MyPoint=1;

   
    
   
	StopLoss_BUY_1 = StopLoss_BUY_1*MyPoint;
	if(!comprobarStopLoss(StopLoss_BUY_1)){
		Alert("StopLoss: Se elimina StopLoss_BUY_1 al ser menor que el mínimo para " + Symbol() + ": " + DoubleToStr(MarketInfo(Symbol(), MODE_STOPLEVEL),0));
		StopLoss_BUY_1=0;
	}
	StopLoss_SELL_1 = StopLoss_SELL_1*MyPoint;
	if(!comprobarStopLoss(StopLoss_SELL_1)){
		Alert("StopLoss: Se elimina StopLoss_SELL_1 al ser menor que el mínimo para " + Symbol() + ": " + DoubleToStr(MarketInfo(Symbol(), MODE_STOPLEVEL),0));
		StopLoss_SELL_1=0;
	}
	TakeProfit_BUY_1 = TakeProfit_BUY_1*MyPoint;
	if(!comprobarTakeProfit(TakeProfit_BUY_1)){
		Alert("TakeProfit: Se elimina TakeProfit_BUY_1 al ser menor que el mínimo para " + Symbol() + ": " + DoubleToStr(MarketInfo(Symbol(), MODE_STOPLEVEL),0));
		TakeProfit_BUY_1=0;
	}
	TakeProfit_SELL_1 = TakeProfit_SELL_1*MyPoint;
	if(!comprobarTakeProfit(TakeProfit_SELL_1)){
		Alert("TakeProfit: Se elimina TakeProfit_SELL_1 al ser menor que el mínimo para " + Symbol() + ": " + DoubleToStr(MarketInfo(Symbol(), MODE_STOPLEVEL),0));
		TakeProfit_SELL_1=0;
	}

//----

   bAllowStrategy = checkStrategy();
   
   Comment("MagicNumber: " + MagicNumber);
   if(DDStop> 0){
      Comment("MN: " + MagicNumber + " DDStop activo: " + DDStop);
   }

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//----
    if(IsTesting()){
        Print("******************************************************");
        Print("*-*-*-*-*- Resumen de Alphadvisor *-*-*-*-*");
        Print("******************************************************");
        Print("Velas alcistas: " + contA);
        Print("Velas bajistas: " + contB);
        Print("Velas planas: " + contI);
        long contTotal=contA+contB;
        Print("Velas totales: " + contTotal);
        Print("******************************************************");   
    }
//----
   
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
void OnTick()
  {
    if( bAllowStrategy == false ) return (0);   

    //para el resumen
    if(IsTesting() && AB_OrdenesAbiertasEA(0, 0)){
        if(Open[1]<Close[1]) contA++;
        else if(Open[1]>Close[1]) contB++;
        else contI++;         
     }  

    //Para parada por DD 
    if(DDStop> 0 && DDPips >= DDStop){
       Comment("MN: " + MagicNumber + " DDStop ejec: " + DDStop);
       AB_CerrarPosiciones(0);
       Print("Se para el robot " + MagicNumber + " debido a que su DD actual " + DoubleToStr(DDPips) + " ha alcanzado su DD de stop "  + DoubleToStr(DDStop) + ". Se cierran todas sus posiciones abiertas.");
       Alert("Se para el robot " + MagicNumber + " debido a que su DD actual " + DoubleToStr(DDPips) + " ha alcanzado su DD de stop "  + DoubleToStr(DDStop) + ". Se cierrran todas sus posiciones abiertas.");      
       ExpertRemove();
    }

    if(MaxSpreadTolerable>0){
        if(Ask-Bid>MaxSpreadTolerable*Point*MyPoint) return;
    }

//----
   	if (!AB_NuevaVela("RB_OIL_KD_V0.1", 1, false, 0)) return;

		if ((iADX( NULL, 0, period_ADX, 0, 0, 1)>VALOR_ADX_ENTRADA) && (iClose(NULL, 0, 1)>iClose(NULL, 0, DIAS_CLOSE_COMPRA))){
			TakeProfit_BUY_1=StopLoss_BUY_1*RATIO_SL_TP;
			if(AB_Comprar("BUY_1", StopLoss_BUY_1, TakeProfit_BUY_1, getFixedLot( Lote_BUY_1 ), "", 0)){
			}
		}

		if ((iADX( NULL, 0, period_ADX, 0, 0, 1)>VALOR_ADX_ENTRADA) && (iClose(NULL, 0, 1)<iClose(NULL, 0, DIAS_CLOSE_VENTA))){
			TakeProfit_SELL_1=StopLoss_SELL_1*RATIO_SL_TP;
			if(AB_Vender("SELL_1", StopLoss_SELL_1, TakeProfit_SELL_1, getFixedLot( Lote_SELL_1 ), "", 0)){
			}
		}



//----

   if(DDStop>0){
      DDPips = getDrawDown(MagicNumber);
   }

   
  }

//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
{  
   double ret=0.0;
   
   if(IsOptimization()){ 
        if(custom == criterio_br){
           double  profit = TesterStatistics(STAT_PROFIT);
           double  max_dd = TesterStatistics(STAT_BALANCE_DD);
           if(max_dd != 0.0)
              ret = profit/max_dd;
           else
             ret=-1;
        }else if(custom == criterio_sqn){
            int hstTotal=OrdersHistoryTotal();
            double tradesProfits[];
            ArrayResize(tradesProfits, hstTotal);
            double totalProfit = 0.0;
            for(int i=0;i<hstTotal;i++)
            {                
                OrderSelect(i,SELECT_BY_POS,MODE_HISTORY);
                tradesProfits[i]=OrderProfit();
                totalProfit += tradesProfits[i];
            }            

            if(hstTotal != 0)
                double average = totalProfit/hstTotal;

            double stdDev = standardDeviation(tradesProfits, average);
            if(stdDev != 0.0)               
                ret = (average / stdDev) * MathSqrt(hstTotal);
            else
               ret = -1;
         }else if(custom == criterio_kratio){
            double acumPips=0.0;
            double acumPipsArr[];
            ArrayResize(acumPipsArr,OrdersHistoryTotal());
            for(int j = 0; j<OrdersHistoryTotal();j++){
               OrderSelect(j, SELECT_BY_POS, MODE_HISTORY);
               
               if ( OrderType() == OP_BUY ) {               
                  acumPips += ( OrderClosePrice() - OrderOpenPrice() ) / (Point*MyPoint);
               }else if ( OrderType() == OP_SELL ) {
                  acumPips += ( OrderOpenPrice() - OrderClosePrice() ) / (Point*MyPoint);
               }
               
               acumPipsArr[j]=acumPips;
               
            }
            
            ret = getKRatio(acumPipsArr);

        }   
    }
   return (ret);
}
//+------------------------------------------------------------------+

