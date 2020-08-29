//+------------------------------------------------------------------+
//|                             C_BASIC_OPTIMIZATION_LOG_BUCKETS.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property strict
//+------------------------------------------------------------------+
//| C_BASIC_OPTIMIZATION_LOG_BUCKETS Class                                                      |
//+------------------------------------------------------------------+
class C_BASIC_OPTIMIZATION_LOG_BUCKETS
{
private:
   //Private Variables
   datetime m_dtStart;
   int m_intNoBuckets;
   int m_intNoDaysInBucket;
   string m_strFileName;
   string m_strWhereIsTheLog;
   string m_strWhereIsTheStrategyTesterLog;
   string m_strEATitles[];
   datetime m_dtBucketEnd[];
   int m_intBucketNoTrades[];
   double m_dblBucketProfit[];
   bool m_boolBucketLastTradeBreach[];
   
   //Private Functions
   void BuildBucketArrays();
   string GenerateDefaultFileName();
   void WriteLogFileTitles();
   void AppendStringToLog(const string strInput);
   void CalculateTradeHistoryCharacteristics(int intMagicNumber, int &intNoTrades, 
                                 int &intNoWins,double &dblMaxDrawdown, double &dblTotalTradeProfit);
   int getBucketIndex(datetime dtOrderOpen);
public:
   //Public Variables
   
   //Constructor and Destructor
   C_BASIC_OPTIMIZATION_LOG_BUCKETS(datetime dtStart, int intNoBuckets, int intNoDaysInBucket, string & strEATitles[]);
   ~C_BASIC_OPTIMIZATION_LOG_BUCKETS();
   
   //Public Functions
   void UpdateLog(int intMagicNumber, string & strEAParameterValues[]);
   void PrintLocationOfLogFiles();
   void RemoveLogFile();
   void ArchiveAndRemoveLogFile();
   bool FileExists();
};
//+------------------------------------------------------------------+
//|  Constructor                                                     |
//+------------------------------------------------------------------+
void C_BASIC_OPTIMIZATION_LOG_BUCKETS::C_BASIC_OPTIMIZATION_LOG_BUCKETS(datetime dtStart, int intNoBuckets, int intNoDaysInBucket, string & strEATitles[])
{
   //-- Store the information on buckets
   this.m_dtStart = dtStart;
   this.m_intNoBuckets = intNoBuckets;
   this.m_intNoDaysInBucket = intNoDaysInBucket;
   
   this.BuildBucketArrays();
   
   //-- Generate the default filename for this log
   this.m_strFileName = GenerateDefaultFileName();
   
   //Update WhereIsTheLog so that the developer can find out where the live log
   //and tester log file should be.
   string strTerminalPath = TerminalInfoString(TERMINAL_DATA_PATH);
   this.m_strWhereIsTheLog=strTerminalPath+"\\MQL4\\Files\\"+this.m_strFileName;
   this.m_strWhereIsTheStrategyTesterLog=strTerminalPath+"\\tester\\files\\"+this.m_strFileName;

   //-- In Constructor you must pass in an array of the EA Parameter Titles.
   int intNoTitles = ArraySize(strEATitles);
   ArrayResize(this.m_strEATitles,intNoTitles,intNoTitles);
   ArrayCopy(this.m_strEATitles,strEATitles);
   
   //-- If the log file does not exist, then write the EA Titles to the log file
   if(!this.FileExists())
   {
      this.WriteLogFileTitles();
   }
   
}
//+------------------------------------------------------------------+
//|  Destructor                                                     |
//+------------------------------------------------------------------+
C_BASIC_OPTIMIZATION_LOG_BUCKETS::~C_BASIC_OPTIMIZATION_LOG_BUCKETS()
{

   //-- Free up the array
   ArrayFree(this.m_strEATitles);
   ArrayFree(m_dtBucketEnd);
   ArrayFree(this.m_intBucketNoTrades);
   ArrayFree(this.m_dblBucketProfit);
   
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|  Private Functions                                               |
//+------------------------------------------------------------------+
void C_BASIC_OPTIMIZATION_LOG_BUCKETS::BuildBucketArrays()
{

   //-- The bucket arrays should have a dimension equal to the number of
   //-- buckets.   The number of trades and P&L should be initiated at zero.
   ArrayResize(this.m_dtBucketEnd,this.m_intNoBuckets);
   ArrayResize(this.m_intBucketNoTrades, this.m_intNoBuckets);
   ArrayResize(this.m_dblBucketProfit, this.m_intNoBuckets);
   ArrayResize(this.m_boolBucketLastTradeBreach, m_intNoBuckets);
   
   //-- Initiate the end dates of the bucket
   for(int i =0; i<this.m_intNoBuckets;i++)
   {
      //-- I don't want to accidentally breach the integer limits using (i+1)*nosecondsinday
      if(i==0)
      {
         this.m_dtBucketEnd[i] = this.m_dtStart + this.m_intNoDaysInBucket*60*60*24;
         this.m_intBucketNoTrades[i] = 0;
         this.m_dblBucketProfit[i] = 0.0;
         this.m_boolBucketLastTradeBreach[i] = false;
      }
      else
      {
         this.m_dtBucketEnd[i] = this.m_dtBucketEnd[i-1] + this.m_intNoDaysInBucket*60*60*24;
         this.m_intBucketNoTrades[i] = 0;
         this.m_dblBucketProfit[i] = 0.0;
         this.m_boolBucketLastTradeBreach[i] = false;
      }
   }
   
   return;
   
}
string C_BASIC_OPTIMIZATION_LOG_BUCKETS::GenerateDefaultFileName()
{
   //-- Defines strings
   string strSymbol, strRet = "Opt_";
   
   //-- Remove unusual characters from the symbol
   strSymbol = Symbol();
   StringReplace(strSymbol,"+","");
   StringReplace(strSymbol,"-","");
   StringReplace(strSymbol,".","");
   StringReplace(strSymbol,"=","");
   
   //-- Add symbol to filename
   strRet += strSymbol;
   
   //-- Now add the timeframe
   strRet += IntegerToString(PeriodSeconds()/60);
   
   strRet += ".txt";
   
   return strRet;
   
}
void C_BASIC_OPTIMIZATION_LOG_BUCKETS::WriteLogFileTitles()
{
   /*
   This generates the first line of the log file that should be generated
   when the log file is first created.   We use the EA Parameters then
   add extra ones calculated by the optimization log.
   */
   
   string strWrite="";
   
   //--Add EA Parameters
   for(int i=0;i<ArraySize(this.m_strEATitles);i++)
   {
      strWrite += (this.m_strEATitles[i] + ";");
   }
   
   //--Now add the Total P&L and TotalTrades
   strWrite += "Total P&L;Total No Trades;";
   
   //--Now add the extra bucket titles
   for(int i=0;i<this.m_intNoBuckets;i++)
   {
      strWrite += "BucketNoTrades_" + IntegerToString(i+1) + ";";
      strWrite += "BucketProfit_" + IntegerToString(i+1) + ";";
      strWrite += "Bucket_LastTradeBreach_" + IntegerToString(i+1) + ";";
      strWrite += "BucketEndDate_" + IntegerToString(i+1) + ";";
   }
   
   //--Now write the files
   this.AppendStringToLog(strWrite);
   
}

void C_BASIC_OPTIMIZATION_LOG_BUCKETS::AppendStringToLog(const string strInput)
{
   //This function opens the Log File, moves to the end of the file and then appends the input
   //string to the file.   Returns (ie \r\n) are added by this routine onto the end of the string.
   
   //Reset the last error
   ResetLastError();
   
   //Open the file - must be read and write for appending to files.
   int intFileHandle=FileOpen(this.m_strFileName,FILE_READ|FILE_WRITE|FILE_TXT);
   
   //If the file has been opened successfully, write to it
   if(intFileHandle!=INVALID_HANDLE)
   {
      //Find the End of the file
      if(!FileSeek(intFileHandle,0,SEEK_END))   Print(__FUNCTION__,"File Seek Error ",GetLastError());
      
      //Write the String
      if(FileWriteString(intFileHandle,strInput+"\r\n")<=0) Print(__FUNCTION__,"File Write Error ",GetLastError());
      
      //Close the file
      FileClose(intFileHandle);
   }
   else
   {
      Print(__FUNCTION__,"Failed to open file ",this.m_strFileName," ",GetLastError());
   }
   
   return;
}
void C_BASIC_OPTIMIZATION_LOG_BUCKETS::CalculateTradeHistoryCharacteristics(int intMagicNumber, int &intNoTrades, 
                                 int &intNoWins,double &dblMaxDrawdown, double &dblTotalTradeProfit)
{
   
   //-- update orders history total
   intNoTrades = OrdersHistoryTotal();
   
   //-- update number of wins and drawdown
   int intCount=0, intCountWin=0;
   double dblIndex=0, dblMax=0, dblMin=0;
   dblMaxDrawdown = 0;
   
   for(int i=0;i<intNoTrades;i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
      {
         if(OrderSymbol()==Symbol() && OrderMagicNumber()==intMagicNumber &&
            (OrderType()==OP_BUY || OrderType()==OP_SELL))
         {  
            //-- Update count of actual trades (not limit/stop)
            intCount++;
            
            //-- Update the trade p&L
            double dblProfit = OrderProfit()+OrderCommission()+OrderSwap();
            
            //-- Update count wins
            if(dblProfit>0)  intCountWin++;
            
            //-- update profit index
            dblIndex += dblProfit;
           
            //--If index goes above max index, reset the minimum figure
            //--encountered to the index level, otherwise min is lowest index
            dblMin = (dblIndex > dblMax) ? dblIndex : MathMin(dblIndex, dblMin);
            
            //--Update max index
            dblMax = MathMax(dblIndex, dblMax);
            
            dblMaxDrawdown = (dblMax-dblMin) > dblMaxDrawdown ? (dblMax-dblMin) : dblMaxDrawdown;  
            
            //--Update the bucket information
            int iB = this.getBucketIndex(OrderOpenTime());
            
            if(iB >= 0)
            {
               this.m_intBucketNoTrades[iB]++;
               this.m_dblBucketProfit[iB] += dblProfit;
               if(OrderCloseTime() > 0)
               {
                  if(OrderCloseTime() > this.m_dtBucketEnd[iB])
                  {
                     this.m_boolBucketLastTradeBreach[iB] = true;
                  }
               }
            }
         }
      }
   }
   
   //-- update the final no wins and no trades
   intNoTrades = intCount;
   intNoWins = intCountWin;
   
   //-- update the final maximum drawdown
   dblMaxDrawdown = (dblMax-dblMin) > dblMaxDrawdown ? (dblMax-dblMin) : dblMaxDrawdown;
                     
   //-- Update the total trade profit with dblIndex.
   dblTotalTradeProfit = dblIndex;

}
int C_BASIC_OPTIMIZATION_LOG_BUCKETS::getBucketIndex(datetime dtOrderOpen)
{
   int intRet = -1;
   for(int i=0;i<ArraySize(this.m_dtBucketEnd);i++)
   {
      if(i==0)
      {
         if(dtOrderOpen >= this.m_dtStart && dtOrderOpen < this.m_dtBucketEnd[i])
         {
            intRet = i;
            break;
         }
      }
      else if(dtOrderOpen >= this.m_dtBucketEnd[i-1] && dtOrderOpen < this.m_dtBucketEnd[i])
      {
            intRet = i;
            break;
      }
   }
   
   return intRet;
}
//+------------------------------------------------------------------+
//|  Public Functions                                                |
//+------------------------------------------------------------------+
void C_BASIC_OPTIMIZATION_LOG_BUCKETS::UpdateLog(int intMagicNumber, string & strEAParameterValues[])
{
   //-- Check the array size is sensible
   if(ArraySize(strEAParameterValues) != ArraySize(this.m_strEATitles))
   {
      Print("*** ERROR - PARAMETER VALUE ARRAY SIZE DIFFERENT TO PARAMETER TITLE ARRAY SIZE");
   }
   
   //-- Variable dec to write to file
   string strWrite = "";
   
   //-- Add the parameter values
   for(int i=0;i<ArraySize(strEAParameterValues);i++)
   {
      strWrite += (strEAParameterValues[i] + ";");
   }
   
   //-- Calculate no trades, no wins and max drawdown and populate the bucket arrays.
   double dblMaxDrawdown, dblTotalTradeProfit=0;
   int intNoTrades, intNoWins;
   this.CalculateTradeHistoryCharacteristics(intMagicNumber, intNoTrades,
                                          intNoWins, dblMaxDrawdown, dblTotalTradeProfit);
   
   strWrite += DoubleToString(dblTotalTradeProfit,4)+";";
   strWrite += IntegerToString(intNoTrades)+";";
   
   for(int i=0;i<this.m_intNoBuckets;i++)
   {
      strWrite += IntegerToString(this.m_intBucketNoTrades[i]) + ";";
      strWrite += DoubleToString(this.m_dblBucketProfit[i],4) + ";";
      strWrite += this.m_boolBucketLastTradeBreach[i] ? "True;" : "False;";
      strWrite += TimeToString(this.m_dtBucketEnd[i],TIME_DATE) + ";";
   }
   
   //-- Finally update the log
   this.AppendStringToLog(strWrite); 
   
}

void C_BASIC_OPTIMIZATION_LOG_BUCKETS::PrintLocationOfLogFiles()
{
   //Call this function at the end of an EA to let the developer/user know where the log file is stored.
   Print(this.m_strWhereIsTheStrategyTesterLog); 
   Print("Location of Strategy Tester Log File:");
   Print(this.m_strWhereIsTheLog);
   Print("Location of Standard Log File:");
     
   return;
}
void C_BASIC_OPTIMIZATION_LOG_BUCKETS::RemoveLogFile()
{
   //This just deletes the log file
   FileDelete(this.m_strFileName);
   return;
}
void C_BASIC_OPTIMIZATION_LOG_BUCKETS::ArchiveAndRemoveLogFile()
{
   //If there is not a BUP directory it creates it.   It then deletes any BUP versions of the filename from this directory
   //and copys the file over it.   A new log file is then created.
   //It is best if this is called during the Init stage of an EA so that we have prepaired a new log file for data
   
   if(!FileIsExist("BUP"))
   {
      FolderCreate("BUP");
   }
   
   FileDelete("Bup\\"+this.m_strFileName);
   FileCopy(this.m_strFileName,0,"BUP\\"+this.m_strFileName,FILE_REWRITE);
   FileDelete(this.m_strFileName);
   return;
   
}
bool C_BASIC_OPTIMIZATION_LOG_BUCKETS::FileExists()
{
   string strFile=this.m_strFileName;
   bool boolRet=FileIsExist(strFile);
   return boolRet;
}