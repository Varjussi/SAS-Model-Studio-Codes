/* SAS code */

*%put _all_;
*options mprint;

/* We just simply time the whole prosess... */
data _null_;
   Datetime = datetime();
   put Datetime= datetime20.3;
   call symput("_START_DT_", Datetime);
run;

/* We start the process by counting the cumulative number of true positives
and negatives for each row sorted by event probability. */
data CASUSER._SORTED_;
   set &dm_data. (
      keep  = &dm_partitionvar. EM_EVENTPROBABILITY &dm_dec_target.);
   by &dm_partitionvar.  EM_EVENTPROBABILITY;

/* The target variable may be either numeric or character. */
   if "&dm_dec_type." eq "N" then do;
      True_Positive = (&dm_dec_target. = &dm_dec_event.);
      True_Negative = (&dm_dec_target. = &dm_dec_nonevent.);
      end;
   else do;
      True_Positive = (&dm_dec_target. = "&dm_dec_event.");
      True_Negative =  (&dm_dec_target. = "&dm_dec_nonevent.");
      end;

   Tot_True_Positives + True_Positive;
   Tot_True_Negatives + True_Negative;
run;

/* Then we reverse the order of the dataset and capture the total number
of true positives and negatives from the first row. */
data CASUSER._SORTED_NEW_ ;
   set CASUSER._SORTED_;
   retain 
      _Tot_True_Positives 
      _Tot_True_Negatives;
   by &dm_partitionvar. descending EM_EVENTPROBABILITY;

/* Retain the Total number of truies psotiovas and negatives from the 
   first row per each Partition. */ 
   if first.&dm_partitionvar. then do;
      _Tot_True_Positives = Tot_True_Positives;
      _Tot_True_Negatives = Tot_True_Negatives;
      end;

   True_Positives + True_Positive;
   True_Negatives + True_Negative;
   False_Negatives = (_Tot_True_Positives - True_Positives);
   False_Positives = (_Tot_True_Negatives - True_Negatives);

/* And then we can calculate the sensitivity and specificity for each row. */
   Sensitivity = (True_Positives) / (True_Positives + False_Negatives);
   Specificity = (False_Positives) / (False_Positives + True_Negatives);
run;


/* The ROC curve uses the 1-Specificity as the X- axis the Y axis is sesitivity.
As there may be several different sensitivity values for each 1-specificity values
we choose the largest of these values. */
data  &dm_lib.._ROC_;
   length Partition $ 12.;
   set CASUSER._SORTED_NEW_ ;
   by &dm_partitionvar. descending Specificity Sensitivity;

/* Calculate the 1-Specificity for the X axis variable. */
   Specificity_Complement = 1 - Specificity;

/* Write out the different partitioning values. */
   select (&dm_partitionvar.);
      when (&dm_partition_valid_val.)  Partition = "Validation";
      when (&dm_partition_train_val.)  Partition = "Train";
      when (&dm_partition_test_val.)   Partition = "Test";
      otherwise Partition = "<missing>";
   end;       

/* Ouput only the largest sensitivity value. */
   if last.Specificity then output;

   label 
      Specificity_Complement = "1 - Specificity"
      Sensitivity = "Sensitivity"
      Partition = "Partition";
run;

/* The AUC is calcualted from the ROC curve as the area under the curve. The curve
consists of several trapezoids with base being the difference between two consecutive 
1-Speciofoty values and hight being the sum of consecutive sesitivity vauyes divide by 2.*/
data &dm_lib.._AUC_(keep = Partition AUC); 
   set &dm_lib.._ROC_;
   by &dm_partitionvar. Specificity_Complement;

/* Initilise the AUC for each partitoning. */
   if first.&dm_partitionvar. then do;
      AUC = 0;
      Specificity_Complement = .;
      Sensitivity = .;
      end;

/* Cacluate the area of each trapezoid.*/
   Trapezoid = (Specificity_Complement - lag(Specificity_Complement)) * (Sensitivity + lag(Sensitivity)) / 2;
/* Calculate the total value iof trapez9ids. */
   AUC + Trapezoid;

/* We only  need the totalö are per each partioning. */
   if last.&dm_partitionvar. then output;
run; 

/* Crete wabntd reports. Would there be need any additional rteports? */
%dmcas_report(dataset=_AUC_, reportType=Table, description=%nrbquote(Exact AUC));

%dmcas_report(dataset=_ROC_, reportType=SeriesPlot, x=Specificity_Complement,
    y=Sensitivity, group= Partition, description=%nrbquote(Exact ROC Plot));

/* Let's do some house keeping for the common CAS libraries we used. */
proc datasets lib=CASUSER noprint;
      delete _SORTED_;
      delete _SORTED_NEW_;
quit;

/* We just simply time the whole prosess... */
data _null_;
   Datetime = datetime();
   put Datetime= datetime20.3;
   Duration = Datetime - &_START_DT_.;
   put Duration= time12.3;
run;

*options nomprint;

