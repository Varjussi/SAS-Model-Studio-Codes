/* SAS code */
%let _GROUPS = 100;

options mprint;

/* We start the process by setting the events to have a value 1 for counting purposes. */
data CASUSER._EVENT_FLAGS_;
   set &dm_data. (
      keep = &dm_partitionvar. EM_EVENTPROBABILITY &dm_dec_target.);
/* The target variable may be either numeric or character. */
   if "&dm_dec_type." eq "N" 
      then Event_Flg = (&dm_dec_target. = &dm_dec_event.);
      else Event_Flg = (&dm_dec_target. = "&dm_dec_event.");
run;

/* We decide the wanted percentile groups. */
proc rank data = CASUSER._EVENT_FLAGS_ 
      out = CASUSER._EVENT_RANKED_ 
      ties = low descending 
      groups = &_GROUPS.;
   by &dm_partitionvar.;
   var EM_EVENTPROBABILITY;
   ranks Prob_Rank;
run;

/* The percentage of the 1's is the captured response for each percentile. */
proc freq data=CASUSER._EVENT_RANKED_ noprint;
   tables Prob_Rank / out=CASUSER._EVENT_COUNTS_ outcum;
   weight Event_Flg;
   by &dm_partitionvar.;
run;

/* Let's fix the results for printing. */
data &dm_lib..FreqCount;
   set CASUSER._EVENT_COUNTS_;
   by &dm_partitionvar.;

/* Ranks start with 0 percentile, so let's advance them by 1.*/
   Prob_Rank = Prob_Rank + 1;
/* Write out the different partitioning values. */
   select (&dm_partitionvar.);
      when (&dm_partition_valid_val.)  Partition = "Validation";
      when (&dm_partition_train_val.)  Partition = "Train";
      when (&dm_partition_test_val.)   Partition = "Test";
      otherwise Partition = "<missing>";
   end;    

   if first.&dm_partitionvar. then do;
      Prob_Rank = 0;
      Percent = .;
      Cum_pct = 0;
      output;
      end;

   output;

   if last.&dm_partitionvar. then do;
      Prob_Rank = &_GROUPS.;
      Percent = .;
      Cum_pct = 100;
      output;
      end;

   label Prob_Rank = "Percentile";
run; 

%dmcas_report(dataset=FreqCount, reportType=SeriesPlot, x= Prob_Rank,
    y= Percent, group= Partition, description=%nrbquote(Captured Response Percentage));

%dmcas_report(dataset=FreqCount, reportType=SeriesPlot, x= Prob_Rank,
    y= Cum_Pct, group= Partition, description=%nrbquote(Cumulative Captured Response Percentage));


options nomprint;


