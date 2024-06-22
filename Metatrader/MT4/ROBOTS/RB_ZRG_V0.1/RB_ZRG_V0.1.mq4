//                                                    RB_ZRG_V0.1.mq4
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
string NombreDelEA = "RB_ZRG_V0.1";
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
extern double PIPS_ZONA_COBERTURA = 50;
extern int StopLoss = 0;
extern int TakeProfit = 0;
extern double LIMITE_SUP_COBERTURA = 0.0;
extern double LIMITE_INF_COBERTURA = 0.0;
extern bool ACTIVAR_BOT = true;
extern double TAKE_PROFIT = 0.0;
extern double TAKE_PROFIT_OBJETIVO = 0.0;
extern int LIMITE_ORDENES = 0;
extern double ICLOSE_ANT = 0.0;
extern double TAKE_PROFIT_SELL = 0.0;
extern double MULTIPLICADOR_LOTAJE = 0.0;
extern double Lote = 0.1;
extern double LOTAJE_INICIAL = 0.0;
extern int SELL_1_ON = 0;




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

   
    
   
	StopLoss = StopLoss*MyPoint;
	if(!comprobarStopLoss(StopLoss)){
		Alert("StopLoss: Se elimina StopLoss al ser menor que el mínimo para " + Symbol() + ": " + DoubleToStr(MarketInfo(Symbol(), MODE_STOPLEVEL),0));
		StopLoss=0;
	}
	TakeProfit = TakeProfit*MyPoint;
	if(!comprobarTakeProfit(TakeProfit)){
		Alert("TakeProfit: Se elimina TakeProfit al ser menor que el mínimo para " + Symbol() + ": " + DoubleToStr(MarketInfo(Symbol(), MODE_STOPLEVEL),0));
		TakeProfit=0;
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
   			if ((ACTIVAR_BOT==true)){
			if (AB_ExisteOrden("BUY_1")){
				if (SELL_1_ON == 1){
					if (AB_ExisteOrden("SELL_1")){
					}else{ 
						AB_CerrarPosiciones(0);
						SELL_1_ON = 0;
					}

				}

			}

			if (AB_ExisteOrden("SELL_1")){
				if (AB_ExisteOrden("BUY_1")){
				}else{ 
					AB_CerrarPosiciones(0);
					SELL_1_ON = 0;
				}

			}

			if (AB_ExisteOrden("BUY_1")){
				if (AB_ExisteOrden("BUY_2")){
					if (AB_ExisteOrden("SELL_1")){
					}else{ 
						AB_CerrarPosiciones(0);
						SELL_1_ON = 0;
					}

				}

			}

			if ((LIMITE_ORDENES>=1)){
				if (AB_ExisteOrdenAbierta("BUY_1")){
				}else{ 
					TAKE_PROFIT = iClose(NULL, 0, 0) +  ( TAKE_PROFIT_OBJETIVO * 10 * Point );
					Lote=LOTAJE_INICIAL;
					if(AB_Comprar("BUY_1", StopLoss, getPipsFromPrice(OP_BUY,TAKE_PROFIT) , getFixedLot( Lote ), "", 0)){
					LIMITE_SUP_COBERTURA = AB_PrecioAperturaOrden("BUY_1");
					LIMITE_INF_COBERTURA = LIMITE_SUP_COBERTURA -  ( PIPS_ZONA_COBERTURA * Point * 10 );
					//static int contadorSYS_B_12345_mm;		

ObjectDelete("LIMITE_SUP_COBERTURA");

ObjectCreate(ChartID(),"LIMITE_SUP_COBERTURA" , OBJ_HLINE , 0,Time[0], LIMITE_SUP_COBERTURA);
           ObjectSetInteger(ChartID(),"LIMITE_SUP_COBERTURA" , OBJPROP_STYLE, STYLE_SOLID);
           ObjectSetInteger(ChartID(),"LIMITE_SUP_COBERTURA" , OBJPROP_COLOR, clrPink);
           ObjectSetInteger(ChartID(),"LIMITE_SUP_COBERTURA", OBJPROP_WIDTH, 0);
					ObjectDelete("LIMITE_INF_COBERTURA");

ObjectCreate(ChartID(),"LIMITE_INF_COBERTURA" , OBJ_HLINE , 0,Time[0], LIMITE_INF_COBERTURA);
           ObjectSetInteger(ChartID(),"LIMITE_INF_COBERTURA" , OBJPROP_STYLE, STYLE_SOLID);
           ObjectSetInteger(ChartID(),"LIMITE_INF_COBERTURA" , OBJPROP_COLOR, clrRed);
           ObjectSetInteger(ChartID(),"LIMITE_INF_COBERTURA", OBJPROP_WIDTH, 0);
					}
				}

			}

			if ((LIMITE_ORDENES>=2)){
				if (AB_ExisteOrdenAbierta("BUY_1")){
					if (AB_ExisteOrdenAbierta("SELL_1")){
					}else{ 
						if ((ICLOSE_ANT>=LIMITE_INF_COBERTURA) && (iClose(NULL, 0, 0)<LIMITE_INF_COBERTURA)){
							TAKE_PROFIT_SELL = iClose(NULL, 0, 0) -  ( TAKE_PROFIT_OBJETIVO * 10 * Point );
							Lote=Lote*MULTIPLICADOR_LOTAJE;
							if(AB_Vender("SELL_1", StopLoss, getPipsFromPrice(OP_SELL,TAKE_PROFIT_SELL) , getFixedLot( Lote ), "", 0)){
							SELL_1_ON = 1;
							}
						}

					}

				}

			}

			if ((LIMITE_ORDENES>=3)){
				if (AB_ExisteOrdenAbierta("SELL_1")){
					if (AB_ExisteOrdenAbierta("BUY_1")){
						if (AB_ExisteOrdenAbierta("BUY_2")){
						}else{ 
							if ((ICLOSE_ANT<=LIMITE_SUP_COBERTURA) && (iClose(NULL, 0, 0)>LIMITE_SUP_COBERTURA)){
								Lote=Lote*MULTIPLICADOR_LOTAJE;
								if(AB_Comprar("BUY_2", StopLoss, getPipsFromPrice(OP_BUY,TAKE_PROFIT) , getFixedLot( Lote ), "", 0)){
								}
							}

						}

					}

				}

			}

			if ((LIMITE_ORDENES>=4)){
				if (AB_ExisteOrdenAbierta("BUY_1")){
					if (AB_ExisteOrdenAbierta("SELL_1")){
						if (AB_ExisteOrdenAbierta("BUY_2")){
							if (AB_ExisteOrdenAbierta("SELL_2")){
							}else{ 
								if ((ICLOSE_ANT>=LIMITE_INF_COBERTURA) && (iClose(NULL, 0, 0)<LIMITE_INF_COBERTURA)){
									Lote=Lote*MULTIPLICADOR_LOTAJE;
									if(AB_Vender("SELL_2", StopLoss, getPipsFromPrice(OP_SELL,TAKE_PROFIT_SELL) , getFixedLot( Lote ), "", 0)){
									}
								}

							}

						}

					}

				}

			}

			if ((LIMITE_ORDENES>=5)){
				if (AB_ExisteOrdenAbierta("BUY_1")){
					if (AB_ExisteOrdenAbierta("SELL_1")){
						if (AB_ExisteOrdenAbierta("BUY_2")){
							if (AB_ExisteOrdenAbierta("SELL_2")){
								if (AB_ExisteOrdenAbierta("BUY_3")){
								}else{ 
									if ((ICLOSE_ANT<=LIMITE_SUP_COBERTURA) && (iClose(NULL, 0, 0)>LIMITE_SUP_COBERTURA)){
										Lote=Lote*MULTIPLICADOR_LOTAJE;
										if(AB_Comprar("BUY_3", StopLoss, getPipsFromPrice(OP_BUY,TAKE_PROFIT) , getFixedLot( Lote ), "", 0)){
										}
									}

								}

							}

						}

					}

				}

			}

			if ((LIMITE_ORDENES>=6)){
				if (AB_ExisteOrdenAbierta("BUY_1")){
					if (AB_ExisteOrdenAbierta("SELL_1")){
						if (AB_ExisteOrdenAbierta("BUY_2")){
							if (AB_ExisteOrdenAbierta("SELL_2")){
								if (AB_ExisteOrdenAbierta("BUY_3")){
									if (AB_ExisteOrdenAbierta("SELL_3")){
									}else{ 
										if ((ICLOSE_ANT>=LIMITE_INF_COBERTURA) && (iClose(NULL, 0, 0)<LIMITE_INF_COBERTURA)){
											Lote=Lote*MULTIPLICADOR_LOTAJE;
											if(AB_Vender("SELL_3", StopLoss, getPipsFromPrice(OP_SELL,TAKE_PROFIT_SELL) , getFixedLot( Lote ), "", 0)){
											}
										}

									}

								}

							}

						}

					}

				}

			}

			if ((LIMITE_ORDENES>=7)){
				if (AB_ExisteOrdenAbierta("BUY_1")){
					if (AB_ExisteOrdenAbierta("SELL_1")){
						if (AB_ExisteOrdenAbierta("BUY_2")){
							if (AB_ExisteOrdenAbierta("SELL_2")){
								if (AB_ExisteOrdenAbierta("BUY_3")){
									if (AB_ExisteOrdenAbierta("SELL_3")){
										if (AB_ExisteOrdenAbierta("BUY_4")){
										}else{ 
											if ((ICLOSE_ANT<=LIMITE_SUP_COBERTURA) && (iClose(NULL, 0, 0)>LIMITE_SUP_COBERTURA)){
												Lote=Lote*MULTIPLICADOR_LOTAJE;
												if(AB_Comprar("BUY_4", StopLoss, getPipsFromPrice(OP_BUY,TAKE_PROFIT) , getFixedLot( Lote ), "", 0)){
												}
											}

										}

									}

								}

							}

						}

					}

				}

			}

			if ((LIMITE_ORDENES>=8)){
				if (AB_ExisteOrdenAbierta("BUY_1")){
					if (AB_ExisteOrdenAbierta("SELL_1")){
						if (AB_ExisteOrdenAbierta("BUY_2")){
							if (AB_ExisteOrdenAbierta("SELL_2")){
								if (AB_ExisteOrdenAbierta("BUY_3")){
									if (AB_ExisteOrdenAbierta("SELL_3")){
										if (AB_ExisteOrdenAbierta("SELL_3")){
											if (AB_ExisteOrdenAbierta("SELL_4")){
											}else{ 
												if ((ICLOSE_ANT>=LIMITE_INF_COBERTURA) && (iClose(NULL, 0, 0)<LIMITE_INF_COBERTURA)){
													Lote=Lote*MULTIPLICADOR_LOTAJE;
													if(AB_Vender("SELL_4", StopLoss, getPipsFromPrice(OP_SELL,TAKE_PROFIT_SELL) , getFixedLot( Lote ), "", 0)){
													}
												}

											}

										}

									}

								}

							}

						}

					}

				}

			}

			if ((LIMITE_ORDENES>=9)){
				if (AB_ExisteOrdenAbierta("BUY_1")){
					if (AB_ExisteOrdenAbierta("SELL_1")){
						if (AB_ExisteOrdenAbierta("BUY_2")){
							if (AB_ExisteOrdenAbierta("SELL_2")){
								if (AB_ExisteOrdenAbierta("BUY_3")){
									if (AB_ExisteOrdenAbierta("SELL_3")){
										if (AB_ExisteOrdenAbierta("SELL_3")){
											if (AB_ExisteOrdenAbierta("SELL_4")){
												if (AB_ExisteOrdenAbierta("BUY_5")){
												}else{ 
													if ((ICLOSE_ANT<=LIMITE_SUP_COBERTURA) && (iClose(NULL, 0, 0)>LIMITE_SUP_COBERTURA)){
														Lote=Lote*MULTIPLICADOR_LOTAJE;
														if(AB_Comprar("BUY_5", StopLoss, getPipsFromPrice(OP_BUY,TAKE_PROFIT) , getFixedLot( Lote ), "", 0)){
														}
													}

												}

											}

										}

									}

								}

							}

						}

					}

				}

			}

			if ((LIMITE_ORDENES>=10)){
				if (AB_ExisteOrdenAbierta("BUY_1")){
					if (AB_ExisteOrdenAbierta("SELL_1")){
						if (AB_ExisteOrdenAbierta("BUY_2")){
							if (AB_ExisteOrdenAbierta("SELL_2")){
								if (AB_ExisteOrdenAbierta("BUY_3")){
									if (AB_ExisteOrdenAbierta("SELL_3")){
										if (AB_ExisteOrdenAbierta("SELL_3")){
											if (AB_ExisteOrdenAbierta("SELL_4")){
												if (AB_ExisteOrdenAbierta("BUY_5")){
													if (AB_ExisteOrdenAbierta("SELL_5")){
													}else{ 
														if ((ICLOSE_ANT>=LIMITE_INF_COBERTURA) && (iClose(NULL, 0, 0)<LIMITE_INF_COBERTURA)){
															Lote=Lote*MULTIPLICADOR_LOTAJE;
															if(AB_Vender("SELL_5", StopLoss, getPipsFromPrice(OP_SELL,TAKE_PROFIT_SELL) , getFixedLot( Lote ), "", 0)){
															}
														}

													}

												}

											}

										}

									}

								}

							}

						}

					}

				}

			}

		}

	ICLOSE_ANT = iClose(NULL, 0, 0);
	Comment(
"MagicNumber: "+MagicNumber+"\n",
"LIMITE_SUP_COBERTURA: "+LIMITE_SUP_COBERTURA+"\n",
"LIMITE_INF_COBERTURA: "+LIMITE_INF_COBERTURA+"\n",
"Lote: "+Lote+"\n"
);


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

