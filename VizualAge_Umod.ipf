#pragma rtGlobals=1		// Use modern global access method. - Leave this line as is, as 1st line!
#pragma ModuleName= Iolite_ActiveDRS  	//Leave this line as is, as 2nd line!
	StrConstant DRS_Version_No= "2013.02"  	//Leave this line as is, as 3rd line!
	//****End of Header Lines - do not disturb anything above this line!****


	//****The global strings (SVar) and variables (NVar) below must always be present. Do not alter their names, alter only text to the right of the "=" on each line.**** (It is important that this line is left unaltered)
	GlobalString				IndexChannel 						="U238"
	GlobalString				ReferenceStandard 					="Z_91500"
	GlobalString				DefaultIntensityUnits				="CPS"
	//**** Below are some optional global strings and variables with pre-determined behaviour. If you wish to include these simply remove the two "//" at the beginning of the line. Similarly, if you wish to omit them, simply comment them using "//"
	GlobalString				BeamSecondsMethod				= "Rate of Change"
	GlobalVariable			BeamSecondsSensitivity				=1
	GlobalString				CurveFitType						="Exponential"
	GlobalVariable			MaskThreshold 						=1000
	GlobalVariable			MaskEdgeDiscardSeconds 			=1
	//**** Any global strings or variables you wish to use in addition to those above can be placed here. You may name these how you wish, and have as many or as few as you like**** (It is important that this line is left unaltered)
	GlobalVariable			Sample238_235Ratio	 			=137.88
	GlobalVariable			DefaultStartMask			 		=0
	GlobalVariable			DefaultEndMask			 			=0
	GlobalVariable			MaxBeamDuration			 		=60
	GlobalVariable			FitOutlierTolerance		 			=1.5
	GlobalString				Ignore_235U			 			="Yes"
	//**** If you'd like to set up some preferred settings for the report window you can set these here too
	GlobalString				Report_DefaultChannel				="Final206_238"
	GlobalString				Report_AverageMethod				="weighted (2 S.E.)"
	GlobalString				Report_UncertaintyMethod			="2 S.E. (absolute)"
	GlobalString				Report_OutlierMethod				="None"
	//**** End of optional global strings and variables**** (It is important that this line is left unaltered)
	//certain optional globals are built in, and have pre-determined lists. these are currently: "StandardisationMethod", "OutputUnits"
	//Note that the above values will be the initial values every time the DRS is opened for the first time, but can then be overwritten for that experiment after that point via the button "Edit DRS Variables". This means that the settings for the above will effectively be stored within the experiment, and not this DRS (this is a good thing)
	//DO NOT EDIT THE ABOVE IF YOU WISH TO EDIT THESE VALUES WITHIN A PARTICULAR EXPERIMENT. THESE ARE THE STARTING VALUES ONLY. THEY WILL ONLY BE LOOKED AT ONCE WHEN THE DRS IS OPENED FOR THE FIRST TIME (FOR A GIVEN EXPERIMENT).


	//**** Initialisation routine for this DRS.  Will be called each time this DRS is selected in the "Select DRS" popup menu (i.e. usually only once).
Function InitialiseActiveDRS() //If init func is required, this line must be exactly as written.   If init function is not required it may be deleted completely and a default message will print instead at initialisation.
	SVAR nameofthisDRS=$ioliteDFpath("Output","S_currentDRS") //get name of this DRS (which should have been already stored by now)

	//###########################################################	
  	// JAP
	Print "DRS initialised:  VizualAge U(Th)Pb zircon laser ablation module for ICP-MS, \"" + nameofthisDRS + "\", Version " + DRS_Version_No + "\r"
  
  	// Initialize VisualAge
	If (strlen(FunctionInfo("VAInit")) == 0)
		printabort("VisualAge isn't loaded!")
	Else
		Execute "VAInit()" 
	EndIf
	// !JAP
	//###########################################################	
End //**end of initialisation routine


//###########################################################	
// JAP
// Function used to make a 204Hg wave if all we have is a 204Pb wave
Function MakeHgWave()
	Wave Pb204 = $ioliteDFPath("input", "Pb204")
	Wave Pb204_time = $ioliteDFPath("input", "Pb204_time")
	Variable NoOfPoints = numpnts(Pb204)
	Wave Hg204 = $makeioliteWave("input", "Hg204", n=NoOfPoints)//$IoliteDFPath("input", "Hg204")
	Wave Hg204_time = $makeioliteWave("input", "Hg204_time", n = NoOfPoints)
	Redimension/D Hg204
	Redimension/D Hg204_time
	Hg204_time = Pb204_time
	Hg204 = Pb204
	SVAR ListOfInputChannels=$ioliteDFpath("input","GlobalListOfInputChannels") //Get reference to "GlobalListOfInputChannels", in the Input folder, and is a list of the form "ChannelName1;ChannelName2;..."
	ListOfInputChannels = RemoveFromList("Hg204", ListOfInputChannels)
	ListOfInputChannels += "Hg204;"
End

Function Do208Correction()
	String IntName
	Variable c86
	Variable c76
	
	String ListOfIntegrations = GetListOfUsefulIntegrations()

	Prompt IntName, "Which Integration? ", popup, ListOfIntegrations
	Prompt c86, "Common 208Pb/206Pb: "
	Prompt c76, "Common 207Pb/206Pb: "
	
	DoPrompt/HELP="" "Do 208Pb (no Th) correction", IntName, c86, c76
	
	If ( V_Flag )
		Return -1
	EndIf
	
	RemoveCommonPbfromUnknowns208(IntName, c86=c86, c76=c76)
End

Function Do207Correction()
	String IntName
	Variable c76
	
	String ListOfIntegrations = GetListOfUsefulIntegrations()

	Prompt IntName, "Which Integration? ", popup, ListOfIntegrations
	Prompt c76, "Common 207Pb/206Pb: "
	
	DoPrompt/HELP="" "Do 207Pb correction", IntName, c76
	
	If ( V_Flag )
		Return -1
	EndIf
	
	RemoveCommonPbFromUnknowns(IntName, c76=c76)
End

//###########################################################	
// 208Pb based approach to removing common Pb assuming no Th
// DC based on JAP 207Pb Correction 
Function RemoveCommonPbFromUnknowns208(IntName, [c86, c76])
	String IntName
	Variable c86, c76
		
	NVAR UsePbComp = root:Packages:VisualAge:Options:Option_UsePbComp
	NVAR Pb64 = root:Packages:VisualAge:Options:Option_Common64
	NVAR Pb74 = root:Packages:VisualAge:Options:Option_Common74
	NVAR Pb84 = root:Packages:VisualAge:Options:Option_Common84		
	NVAR k = root:Packages:VisualAge:Constants:k	  // 238U/235U ratio
	
	Wave sim = $ioliteDFpath("integration", "m_" + IntName)
	Variable NoOfIntegrations = DimSize(sim,0)-1
	
	If ( ParamIsDefault(c76) )
		c76 = Pb74/Pb64
	EndIf
	If ( ParamIsDefault(c86) )
		c86 = Pb84/Pb64
	EndIf
	
	Wave Final207_206 = $ioliteDFpath("CurrentDRS", "Final207_206")
	Wave Final206_208 = $ioliteDFpath("CurrentDRS", "Raw_206_208")
	Wave Final238_206 = $ioliteDFpath("CurrentDRS", "Final238_206")
	Wave Final207_235 = $ioliteDFpath("CurrentDRS", "Final207_235")
	Wave Final206_238 = $ioliteDFpath("CurrentDRS", "Final206_238")

		
	Wave/z  Index_Time=$ioliteDFpath("CurrentDRS","Index_Time")	// the /z flag used in case runtime lookup fails
	
	Wave FinalNoTh207_206 = $makeioliteWave("CurrentDRS", "FinalNoTh207_206", n = numpnts(Final207_206))
	Wave FinalNoTh238_206 = $makeioliteWave("CurrentDRS", "FinalNoTh238_206", n = numpnts(Final207_206))
	Wave FinalNoTh206_238 = $makeioliteWave("CurrentDRS", "FinalNoTh206_238", n = numpnts(Final207_206))
	Wave FinalNoTh207_235 = $makeioliteWave("CurrentDRS", "FinalNoTh207_235", n = numpnts(Final207_206))
	Wave FinalAgeNoTh207_235 = $makeioliteWave("CurrentDRS", "FinalAgeNoTh207_235", n = numpnts(Final207_206))
	Wave FinalAgeNoTh206_238 = $makeioliteWave("CurrentDRS", "FinalAgeNoTh206_238", n = numpnts(Final207_206))
	Wave FinalAgeNoTh207_206 = $makeioliteWave("CurrentDRS", "FinalAgeNoTh207_206", n = numpnts(Final207_206))
	
	If (WaveMax( FinalAgeNoTh206_238) == 0)  //******* not entirely sure why I am doing this - if the wave  = 0 (first time it is run?) then clears it.  is this because of a memory effect?
		FinalNoTh207_206 =nan
 		FinalNoTh238_206 =nan
 		FinalNoTh206_238 = nan
 		FinalNoTh207_235 = nan
 		FinalAgeNoTh207_235 = nan
		FinalAgeNoTh206_238 = nan
		FinalAgeNoTh207_206 = nan
	EndIf
	
	// Loop through integrations
	Variable i
	For (i = 1; i<=NoOfIntegrations; i = i + 1)

		// Loop through time-slices of current integration
		Variable thisstarttime = sim[i][0][%$"Median Time"]-sim[i][0][%$"Time Range"]
		Variable thisendtime = sim[i][0][%$"Median Time"]+sim[i][0][%$"Time Range"]
		Variable thisstartpoint = ForBinarySearch(Index_Time, thisstarttime) + 1

		if(numtype(Index_Time[thisstartpoint]) == 2)	//if the resulting point was a NaN
			thisstartpoint += 1		//then add 1 to it
		endif

		Variable thisendpoint = ForBinarySearch(index_time, thisendtime)

		if(thisendpoint == -2)	//if the last selection goes over the end of the data
			thisendpoint = numpnts(Index_Time) - 1
		endif
		
		Variable j
		For (j=thisstartpoint; j<=thisendpoint; j = j + 1)
			//use 208/20X of time slice
			Variable s76 = Final207_206[j]
			Variable s86 = 1/Final206_208[j]
			Variable s87 = s86/s76
			Variable f6 = s86/c86
			Variable f7 = s87/(c86/c76)
			
					
			//correct for common Pb
			FinalNoTh206_238[j] = (1 - f6)*Final206_238[j]
			FinalNoTh238_206[j] = 1/FinalNoTh206_238[j]
			FinalNoTh207_235[j] = (1 - f7)*Final207_235[j]
			FinalNoTh207_206[j] = ((s76/s86)-(c76/c86))/((1/s86)-(1/c86))
 			FinalAgeNoTh206_238[j] = Ln(FinalNoTh206_238[j] + 1) / 0.000155125
			FinalAgeNoTh207_235[j] = Ln((FinalNoTh207_235[j]) + 1) / 0.00098485
		
			
		EndFor
		
		// Calculate a reasonable guess at the age:
		//Variable guess = FinalAgeNoTh206_238
		Variable guess = 1e9
				
		Variable l
		For (l=thisstartpoint; l<=thisendpoint; l = l + 1)
		
			// Get current 7/6 ratio:
			Variable m76 = (FinalNoTh207_206[l] + FinalNoTh207_206[l-1] + FinalNoTh207_206[l+1])/3
				
			// If the ratio or age seem unreasonable set age to NaN and skip
			If (numtype(m76) == 2 || guess <= 1 || guess > 5e9 || numtype(guess) == 2)
				FinalAgeNoTh207_206[l] = NaN
				Continue
			EndIf
		
			// Call Newton's method PbPb function:
			FinalAgeNoTh207_206[l] = CalculatePbPbAge(m76, guess)
		EndFor
			
	EndFor
	
	SVAR ListOfOutputChannels=$ioliteDFpath("Output","ListOfOutputChannels")
	ListOfOutputChannels = RemoveFromList("FinalNoTh207_235;FinalNoTh206_238;FinalNoTh238_206;FinalNoTh207_206;FinalAgeNoTh207_235;FinalAgeNoTh206_238;FinalAgeNoTh207_206", ListOfOutputChannels)
	ListOfOutputChannels += "FinalNoTh207_235;FinalNoTh206_238;FinalNoTh238_206;FinalNoTh207_206;FinalAgeNoTh207_235;FinalAgeNoTh206_238;FinalAgeNoTh207_206;"
	string currentdatafolder = GetDataFolder(1)
	setdatafolder $ioliteDFpath("DRSGlobals","")
	SVar ReferenceStandard
	string ListOfOutputsToPropagate = "FinalNoTh207_206; FinalAgeNoTh207_206"
	Propagate_Errors("All", ListOfOutputsToPropagate, "DC207_206", ReferenceStandard)
	ListOfOutputsToPropagate = "FinalNoTh206_238;FinalAgeNoTh206_238;FinalNoTh238_206"
	Propagate_Errors("All", ListOfOutputsToPropagate, "DC206_238", ReferenceStandard)
	ListOfOutputsToPropagate = "FinalNoTh207_235;FinalAgeNoTh207_235;"
	Propagate_Errors("All", ListOfOutputsToPropagate, "DC207_235", ReferenceStandard)
	
End

// 207Pb based approach to removing common Pb
Function RemoveCommonPbFromUnknowns(IntName, [c76])
	String IntName
	Variable c76
	
	NVAR UsePbComp = root:Packages:VisualAge:Options:Option_UsePbComp
	NVAR Pb64 = root:Packages:VisualAge:Options:Option_Common64
	NVAR Pb74 = root:Packages:VisualAge:Options:Option_Common74
	NVAR Pb84 = root:Packages:VisualAge:Options:Option_Common84		
	NVAR k = root:Packages:VisualAge:Constants:k	
	
	Wave sim = $ioliteDFpath("integration", "m_" + IntName)
	Variable NoOfIntegrations = DimSize(sim,0)-1
	
	
	If ( ParamIsDefault(c76) )
		c76 = Pb74/Pb64
	EndIf
	
	Wave Final207_206 = $ioliteDFpath("CurrentDRS", "Final207_206")
	Wave Final238_206 = $ioliteDFpath("CurrentDRS", "Final238_206")
	Wave FinalAge206_238 = $ioliteDFpath("CurrentDRS", "FinalAge206_238")
	Wave/z  Index_Time=$ioliteDFpath("CurrentDRS","Index_Time")	
	
	Wave Final207Age = $makeioliteWave("CurrentDRS", "Final207Age", n = numpnts(Final207_206))
	
	If (WaveMax(Final207Age) == 0)
		Final207Age = nan
	EndIf
	
	Make/O/D/N=(2) xWave, yWave, fit_coefs	
	
	// Loop through integrations
	Variable i
	For (i = 1; i<=NoOfIntegrations; i = i + 1)

		// Loop through time-slices of current integration
		Variable thisstarttime = sim[i][0][%$"Median Time"]-sim[i][0][%$"Time Range"]
		Variable thisendtime = sim[i][0][%$"Median Time"]+sim[i][0][%$"Time Range"]
		
		Variable thisstartpoint = ForBinarySearch(index_time, thisstarttime) + 1

		if(numtype(index_time[thisstartpoint]) == 2)	//if the resulting point was a NaN
			thisstartpoint += 1		//then add 1 to it
		endif

		Variable thisendpoint = ForBinarySearch(index_time, thisendtime)

		if(thisendpoint == -2)	//if the last selection goes over the end of the data
			thisendpoint = numpnts(index_time) - 1
		endif
		
		Variable This38_6 = sim[i][%$"Final238_206"][%$"Mean Intensity"]
		Variable This7_6 = sim[i][%$"Final207_206"][%$"Mean Intensity"]
		
		
		
		Variable j
		For (j=thisstartpoint; j<=thisendpoint; j = j + 1)

			xWave = {0, Final238_206[j]}
			yWave = {c76, Final207_206[j]}
			if ( numtype(xWave[1]) == 2 || numtype(yWave[1]) == 2)
				Final207Age[j] = Nan
				Continue
			EndIf
			CurveFit/ODR=2/X=1/W=2/Q/NTHR=0 line kwCWave=fit_coefs yWave /X=xWave
			Print fit_coefs[1], fit_coefs[0]
			Variable cAge = SolveTWConcordiaLine(fit_coefs[1], fit_coefs[0], 1e6*FinalAge206_238[j])

			Final207Age[j] = cAge

		EndFor
			
	EndFor
	
	SVAR ListOfOutputChannels=$ioliteDFpath("Output","ListOfOutputChannels")
	
	ListOfOutputChannels = RemoveFromList("Final207Age", ListOfOutputChannels)
	ListOfOutputChannels += "Final207Age;"
	string currentdatafolder = GetDataFolder(1)
	setdatafolder $ioliteDFpath("DRSGlobals","")
	SVar ReferenceStandard
	string ListOfOutputsToPropagate = "Final207Age;"
	Propagate_Errors("All", ListOfOutputsToPropagate, "DC206_238", ReferenceStandard)
	
End

Menu "VizualAge"
	"-"
	"Apply 207Pb Correction", Do207Correction()
	"Apply 208Pb Correction", Do208Correction()
End

Function CalculateDose()

	Wave Uppm = $ioliteDFpath("CurrentDRS", "Approx_U_PPM")
	Wave Thppm = $ioliteDFpath("CurrentDRS", "Approx_Th_PPM")
	
	Wave FinalAge206_238 = $iolitedfpath("CurrentDRS", "FinalAge206_238")
	Wave FinalAge207_206 = $iolitedfpath("CurrentDRS", "FinalAge207_206")
	
	Variable Npts = numpnts(Uppm)

	Wave Dose = $makeiolitewave("CurrentDRS", "Dose", n = Npts)
	
	// Loop through each time slice:
	Variable N238, N235, N232
	Variable l235 = 9.8485e-10
	Variable l238 = 1.55125e-10
	Variable l232 = 0.49475e-10
	Variable k = 137.88	
	Variable ct = 0
	Variable Navo = 6.0221413E+23
	
	Variable i
	For( i = 0; i < Npts; i = i + 1 )
		N238 = 0.001*Uppm[i]*1e-6*Navo/238
		N235 = 0.001*(Uppm[i]/k)*1e-6*Navo/235
		N232 = 0.001*Thppm[i]*1e-6*Navo/232
		
		ct = FinalAge206_238[i]
		If (ct > 2000)
			ct = FinalAge207_206[i]
		EndIf
		
		Dose[i] = 8*N238*(exp(l238*ct*1e6)-1) + 7*N235*(exp(l235*ct*1e6)-1) + 6*N232*(exp(l232*ct*1e6)-1)
		
	EndFor		
	SVAR ListOfOutputChannels=$ioliteDFpath("Output","ListOfOutputChannels") 
	ListOfOutputChannels = RemoveFromList("Dose", ListOfOutputChannels)
	ListOfOutputChannels += "Dose;"
End

Function MakeURatioWave()

	Wave Index_Time = $ioliteDFpath("CurrentDRS", "Index_Time")
	Wave URatioWave = $MakeIoliteWave("CurrentDRS", "URatio", n=numpnts(Index_Time))

	NVar Sample238_235Ratio = $ioliteDFPath("DRSGlobals", "Sample238_235Ratio")

	URatioWave = Sample238_235Ratio
	
	SVar ListOfIntermediateChannels = $ioliteDFpath("Output", "ListOfIntermediateChannels")
	ListOfIntermediateChannels = RemoveFromList("URatio", ListOfIntermediateChannels)
	ListOfIntermediateChannels += "URatio;"
	
	SVar ListOfStandards = $ioliteDFpath("integration", "S_ListOfStandards")
	
	String IntegrationList = GetListOfUsefulIntegrations()
	
	Variable i
	For ( i = 0; i < ItemsInList(IntegrationList); i += 1)
		String CurIntName = StringFromList(i, IntegrationList)
	
		Variable ThisRatio = Sample238_235Ratio
		
		If (WhichListItem(CurIntName, ListOfStandards) >= 0)
			Variable RatioInStd = GetValueFromStandard("238U/235U",CurIntName)
			If (numtype(RatioInStd) == 0)
				ThisRatio = RatioInStd
			EndIf
		EndIf

		print CurIntName, ThisRatio

		// Now if the ratio isn't the default, loop through each integration and modify the ratio wave:
		If (ThisRatio != Sample238_235Ratio)		
			
			Wave aim = $ioliteDFpath("integration", "m_" + CurIntName)
			Variable NoOfIntegrations = DimSize(aim,0)-1			
			
			Variable j
			For (j = 1; j <= NoOfIntegrations; j += 1)
		
				Variable thisstarttime = aim[j][0][%$"Median Time"]-aim[j][0][%$"Time Range"]
				Variable thisendtime = aim[j][0][%$"Median Time"]+aim[j][0][%$"Time Range"]
		
				Variable thisstartpoint = ForBinarySearch(Index_Time, thisstarttime) + 1

				If (numtype(Index_Time[thisstartpoint]) == 2)	//if the resulting point was a NaN
					thisstartpoint += 1		//then add 1 to it
				EndIf

				Variable thisendpoint = ForBinarySearch(Index_Time, thisendtime)

				if(thisendpoint == -2)	//if the last selection goes over the end of the data
					thisendpoint = numpnts(Index_Time) - 1
				endif

				URatioWave[thisstartpoint,thisendpoint] = ThisRatio
			EndFor
		EndIf
	EndFor

End

// !JAP
//###########################################################	

//****Start of actual Data Reduction Scheme.  This is run every time raw data is added or the user presses the "crunch data" button.  Try to keep it to no more than a few seconds run-time!
Function RunActiveDRS() //The DRS function name must be exactly as written here.  Enter the function body code below.
	
	ProgressDialog()		//Start progress indicator
	
	//the next 5 lines reference all of the global strings and variables in the header of this file for use in the main code of the DRS that follows.
	string currentdatafolder = GetDataFolder(1)
	setdatafolder $ioliteDFpath("DRSGlobals","")
	SVar IndexChannel, ReferenceStandard, DefaultIntensityUnits, UseOutlierRejection, BeamSecondsMethod, CurveFitType, Ignore_235U
	NVar MaskThreshold, MaskEdgeDiscardSeconds, BeamSecondsSensitivity, MaxBeamDuration, DefaultStartMask, DefaultEndMask, FitOutlierTolerance, Sample238_235Ratio
	setdatafolder $currentdatafolder
	//convert the long names of CurveFitType in the user interface into short labels
	string ShortCurveFitType
	string UserInterfaceList = "Exponential plus optional linear;Linear;Exponential;Double exponential;Smoothed cubic spline;Running median"
	string ShortLabelsList = "LinExp;Lin;Exp;DblExp;Spline;RunMed"
	ShortCurveFitType = StringFromList(WhichListItem(CurveFitType, UserInterfaceList, ";", 0, 0), ShortLabelsList, ";")	//this line extracts the short label corresponding to the user interface label in the above string.
	if(cmpstr(ShortCurveFitType, "") == 0)	//if for some reason the above substitution didn't work, then need to throw an error, as that will have to be fixed
		printabort("Sorry, the DRS failed to recognise the down-hole fractionation model you chose")
	endif
	//Do we have a baseline_1 spline for the index channel, as require this to proceed further?
	DRSabortIfNotWave(ioliteDFpath("Splines", IndexChannel+"_Baseline_1"))	//Abort if [index]_Baseline_1 is not in the Splines folder, otherwise proceed with DRS code below..
	
	SetProgress(5, "Starting baseline subtraction...")
	
	//Next, create a reference to the Global list of Output channel names, which must contain the names of all outputs produced by this routine, and to the inputs 
	SVAR ListOfOutputChannels=$ioliteDFpath("Output","ListOfOutputChannels") //"ListOfOutputChannels" is already in the Output folder, and will be empty ("") prior to this function being called.
	SVAR ListOfIntermediateChannels=$ioliteDFpath("Output","ListOfIntermediateChannels")
	SVAR ListOfInputChannels=$ioliteDFpath("input","GlobalListOfInputChannels") //Get reference to "GlobalListOfInputChannels", in the Input folder, and is a list of the form "ChannelName1;ChannelName2;..."
	//Now create the global time wave for intermediate and output waves, based on the index isotope  time wave  ***This MUST be called "index_time" as some or all export routines require it, and main window will look for it
	wave Index_Time = $MakeIndexTimeWave()	//create the index time wave using the external function - it tries to use the index channel, and failing that, uses total beam
	variable NoOfPoints=numpnts(Index_Time) //Make a variable to store the total number of time slices for the output waves

	//THIS DRS IS A SPECIAL CASE, and has been built to allow a 'partial' data crunch, beginning after the downhole correction of ratios
	NVar OptionalPartialCrunch = $ioliteDFpath("CurrentDRS","OptionalPartialCrunch")
	if(NVar_Exists(OptionalPartialCrunch)!=1)	//if the OptionalPartialCrunch NVar doesn't exist yet then make it here. this will only happen once, the first time the DRS is crunched
		variable/g $ioliteDFpath("CurrentDRS","OptionalPartialCrunch") = 0	//so make the global variable and set it to 0
		NVar OptionalPartialCrunch = $ioliteDFpath("CurrentDRS","OptionalPartialCrunch")	//and reference it
	endif
	//The below Svar is used throughout the DRS, so place it outside the below if command
	String/g $ioliteDFpath("CurrentDRS","Measured_UPb_Inputs")
	SVar Measured_UPb_Inputs = $ioliteDFpath("CurrentDRS","Measured_UPb_Inputs")
	if(OptionalPartialCrunch!=1)	//if this is a normal crunch data then do all of this stuff, otherwise skip to the 'else' after DownHoleCurveFit()
		wave IndexOut = $InterpOntoIndexTimeAndBLSub(IndexChannel)	//Make an output wave for Index isotope (as baseline-subtracted intensity)
		//baseline subtract all input channels. will sieve out the U Pb ones specifically afterwards
		variable CurrentChannelNo
		CurrentChannelNo = 0
		variable NoOfChannels
		NoOfChannels = itemsinlist(ListOfInputChannels) //Create local variables to hold the current input channel number and the total number of input channels
		String NameOfCurrentChannel
		String CurrentElement //Create a local string to contain the name of the current channel, and its corresponding element
		Do //Start to loop through the available channels
			NameOfCurrentChannel=StringFromList(CurrentChannelNo,ListOfInputChannels) //Get the name of the nth channel from the input list
			//Can no longer use the below test, as some inputs from multicollectors are too complex and will not be recognised as elements
			//CurrentElement=GetElementFromIsotope(NameOfCurrentChannel) //get name of the element
			if(cmpstr(NameOfCurrentChannel, IndexChannel)!=0) //if this element is not "null" (i.e. is an element), and it is not the index isotope, then..
				wave ThisChannelBLsub = $InterpOntoIndexTimeAndBLSub(NameOfCurrentChannel)		//use this external function to interpolate the input onto index_time then subtract it's baseline
				ListOfIntermediateChannels+=NameOfCurrentChannel+"_" + DefaultIntensityUnits +";" //Add the name of this new output channel to the list of outputs
			endif //Have now created a (baseline-subtracted channel) output wave for the current input channel, unless it was TotalBeam or index
			
			SetProgress(5+((CurrentChannelNo+1)/NoOfChannels)*10,"Processing baselines")	//Update progress for each channel
			
			CurrentChannelNo+=1 //So move the counter on to the next channel..
		While(CurrentChannelNo<NoOfChannels) //..and continue to loop until the last channel has been processed.
		ListOfIntermediateChannels+=IndexChannel+"_"+DefaultIntensityUnits+";" //Add the name of this new output channel to the list of outputs
		//Now all baseline subtracted waves have been created.
		
		//###########################################################	
		// JAP
		// Do 204Pb = 204Total - F*202Hg
		// where F is the ratio of 204Hg/202Hg determined from the baseline
		Print "Checking if Hg correction should be applied..."
		If (FindListItem("Hg204", ListOfInputChannels) != -1 && FindListItem("Pb204", ListOfInputChannels) != -1)
			Print "Doing Hg correction..."
			Wave Hg204 = $IoliteDFPath("input", "Hg204")
			Wave Hg202 = $IoliteDFPath("input", "Hg202")
			Wave Pb204 = $ioliteDFPath("input", "Pb204")	
		
			Wave Hg204_Spline = $InterpSplineOntoIndexTime("Hg204", "Baseline_1")
			Wave Hg202_Spline = $InterpSplineOntoIndexTime("Hg202", "Baseline_1")
		
			Wave HgRatio = $MakeIoliteWave("CurrentDRS", "HgRatio", n=NoOfPoints)
			HgRatio = Hg204_Spline/Hg202_Spline
	
			// Use this line to use the determined HgRatio spline:
			Pb204 = Hg204 - HgRatio*Hg202
		
			// Use this line to use the expected Hg ratio:
			//Pb204 = Hg204 - 0.22987*Hg202
	
		EndIf
		// !JAP		
		//###########################################################	

		//make a mask for ratios, don't put it on baseline subtracted intermediates, as the full range is useful on these.	
		Wave MaskLowCPSBeam=$DRS_CreateMaskWave(IndexOut,MaskThreshold,MaskEdgeDiscardSeconds,"MaskLowCPSBeam","StaticAbsolute")  //This mask currently removes all datapoints below 1000 CPS on U238, with a sideways effect of 1 second.
		//The below function is called to detect which inputs are present - the format of the inputs can vary depending on the machine used to acquire the data.
		//the function returns a list of the inputs in ascending mass order, with 204 at the very end if present. The list can then be used below to reference the waves in this function
		//As part of the below function that detects a variety of input channel names (they vary depending on the mass spec used), make a global string to use as a reference of which Hg, Pb, Th, U isotopes have been measured (using a key=value; system)
		Measured_UPb_Inputs = "200=no;202=no;204=no;206=no;207=no;208=no;232=no;235=no;238=no;"
		//the "no" values in this string will be replaced by the name of the input channel for each isotope that was measured
		GenerateUPbInputsList(ListOfIntermediateChannels)
		//Now have a key=value string storing either "no" if a channel wasn't measured, or the name of the channel if it was, e.g. "200=no;202=no;204=no;206=Pb206;207=Pb207;208=Pb208;232=Th232;235=no;238=U238;"
		//can now use this string to reference the relevant baseline-subtracted waves
		//At its most basic level this DRS will expect at least Pb 206 and U238. The below lines check if these two are present, and report a failure if they're not
		if(cmpstr(StringByKey("206", Measured_UPb_Inputs, "=", ";", 0), "no") ==0 || cmpstr(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), "no") ==0)
			printabort("It appears that 206Pb or U238 were not measured. The DRS requires that as a minimum these two isotopes were measured.")
		endif
		//In addition to the key=value string used above, want to make flags for which ratios can be calculated - these can then be used throughout the rest of the DRS (note that 204 uses a separate flag)
		variable/G $ioliteDFpath("CurrentDRS","Calculate_206_238")
		variable/G $ioliteDFpath("CurrentDRS","Calculate_207_235")
		variable/G $ioliteDFpath("CurrentDRS","Calculate_208_232")
		variable/G $ioliteDFpath("CurrentDRS","Calculate_207_206")
		variable/G $ioliteDFpath("CurrentDRS","Calculate_206_208")
		NVar Calculate_206_238 = $ioliteDFpath("CurrentDRS","Calculate_206_238")
		NVar Calculate_207_235 = $ioliteDFpath("CurrentDRS","Calculate_207_235")
		NVar Calculate_208_232 = $ioliteDFpath("CurrentDRS","Calculate_208_232")
		NVar Calculate_207_206 = $ioliteDFpath("CurrentDRS","Calculate_207_206")
		NVar Calculate_206_208 = $ioliteDFpath("CurrentDRS","Calculate_206_208")
		//Now set each one, depending on whether the required waves are present (for both UPb ratios check using 238, with the assumption that it will always be available and ok to use, even if 235 wasn't measured)
		Calculate_206_238 = (cmpstr(StringByKey("206", Measured_UPb_Inputs, "=", ";", 0), "no") !=0 && cmpstr(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), "no") !=0)? 1 : 0
		Calculate_207_235 = (cmpstr(StringByKey("207", Measured_UPb_Inputs, "=", ";", 0), "no") !=0 && cmpstr(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), "no") !=0)? 1 : 0
		Calculate_208_232 = (cmpstr(StringByKey("208", Measured_UPb_Inputs, "=", ";", 0), "no") !=0 && cmpstr(StringByKey("232", Measured_UPb_Inputs, "=", ";", 0), "no") !=0)? 1 : 0
		Calculate_207_206 = (cmpstr(StringByKey("207", Measured_UPb_Inputs, "=", ";", 0), "no") !=0 && cmpstr(StringByKey("206", Measured_UPb_Inputs, "=", ";", 0), "no") !=0)? 1 : 0
		Calculate_206_208 = (cmpstr(StringByKey("206", Measured_UPb_Inputs, "=", ";", 0), "no") !=0 && cmpstr(StringByKey("208", Measured_UPb_Inputs, "=", ";", 0), "no") !=0)? 1 : 0
		//Now start referencing the isotopes used in ratio calculation
		string ThisChannelName	//(re-use this string for each of the channels below)
		//Hg200
		ThisChannelName = StringByKey("200", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)
			Wave Hg200_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		endif
		//Hg202
		ThisChannelName = StringByKey("202", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)
			Wave Hg202_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		endif
		//Pb204
		ThisChannelName = StringByKey("204", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)
			Wave Pb204_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		endif
		//Pb206
		ThisChannelName = StringByKey("206", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)
			Wave Pb206_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		endif
		//Pb207
		ThisChannelName = StringByKey("207", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)
			Wave Pb207_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		endif
		//Pb208
		ThisChannelName = StringByKey("208", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)
			Wave Pb208_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		endif
		//Th232
		ThisChannelName = StringByKey("232", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)
			Wave Th232_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		endif
		//U235
		ThisChannelName = StringByKey("235", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)
			Wave U235_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		endif
		//U238
		ThisChannelName = StringByKey("238", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)
			Wave U238_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		endif
		//have now referenced all relevant channels that have been measured
		//Now as a last check, just confirm that 206 and 238 do not have zero point waves
		if((numpnts(Pb206_Beam)==0)||(numpnts(U238_Beam)==0))
			abort "One of the Pb, Th, or U channels are empty or missing, things are going to end badly..."
		endif
		//now check if a 204 beam has been measured and set a flag appropriately so that it can be used elsewhere
		variable Was204Measured
		ThisChannelName = StringByKey("204", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)	//if 204 was measured
			//set the flag to 1
			Was204Measured = 1
			//and reference the relevant wave
			wave Pb204_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		else	//otherwise set the flag to 0
			Was204Measured = 0
		endif
		//now, if 204 has been measured, the flag will be set to 1 and the wave has been referenced, otherwise it will be set to 0

		SetProgress(20,"Calculating raw ratios...")	//Update progress for each channel

		MakeURatioWave()
		Wave URatio = $iolitedfpath("CurrentDRS", "URatio")
		
		if(Calculate_206_238 == 1)
			Wave Raw_206_238=$MakeioliteWave("CurrentDRS","Raw_206_238",n=NoOfPoints)
			Raw_206_238 = Pb206_Beam/U238_Beam * MaskLowCPSBeam
			Wave Raw_Age_206_238=$MakeioliteWave("CurrentDRS","Raw_Age_206_238",n=NoOfPoints)
			Raw_Age_206_238 = Ln(Raw_206_238 + 1) / 0.000155125
			ListOfIntermediateChannels+="Raw_206_238;Raw_Age_206_238;"
		endif
		if(Calculate_207_235 == 1)
			Wave Raw_207_235=$MakeioliteWave("CurrentDRS","Raw_207_235",n=NoOfPoints)
			if(waveexists(U235_Beam) == 1 && cmpstr(Ignore_235U, "No") == 0)
				Raw_207_235 = Pb207_Beam/U235_Beam * MaskLowCPSBeam
			else
//				Raw_207_235 = Pb207_Beam/U238_Beam * Sample238_235Ratio * MaskLowCPSBeam
				Raw_207_235 = Pb207_Beam/U238_Beam * URatio * MaskLowCPSBeam
			endif
			Wave Raw_Age_207_235=$MakeioliteWave("CurrentDRS","Raw_Age_207_235",n=NoOfPoints)
			Raw_Age_207_235 = Ln((Raw_207_235) + 1) / 0.00098485
			ListOfIntermediateChannels+="Raw_207_235;Raw_Age_207_235;"
		endif
		if(Calculate_208_232 == 1)
			Wave Raw_208_232=$MakeioliteWave("CurrentDRS","Raw_208_232",n=NoOfPoints)
			Raw_208_232 = Pb208_Beam/Th232_Beam * MaskLowCPSBeam
			Wave Raw_Age_208_232=$MakeioliteWave("CurrentDRS","Raw_Age_208_232",n=NoOfPoints)
			Raw_Age_208_232 = Ln(Raw_208_232 + 1) / 0.000049475
			ListOfIntermediateChannels+="Raw_208_232;Raw_Age_208_232;"
		endif
		if(Calculate_207_206 == 1)
			//Call the function that will generate a lookup table to be used in calculating 207/206 ages
			Generate207206LookupTable()
			Wave Raw_207_206=$MakeioliteWave("CurrentDRS","Raw_207_206",n=NoOfPoints)
			Raw_207_206 = Pb207_Beam/Pb206_Beam * MaskLowCPSBeam
			Wave Raw_Age_207_206=$MakeioliteWave("CurrentDRS","Raw_Age_207_206",n=NoOfPoints)
			wave LookupTable_76 = $ioliteDFpath("CurrentDRS","LookupTable_76")
			wave LookupTable_age = $ioliteDFpath("CurrentDRS","LookupTable_age")
			Raw_Age_207_206 = interp(Raw_207_206, LookupTable_76, LookupTable_age)
			ListOfIntermediateChannels+="Raw_207_206;Raw_Age_207_206;"
		endif
		if(Calculate_206_208 == 1)
			Wave Raw_206_208=$MakeioliteWave("CurrentDRS","Raw_206_208",n=NoOfPoints)
			Raw_206_208 = Pb206_Beam/Pb208_Beam * MaskLowCPSBeam
			ListOfIntermediateChannels+="Raw_206_208;"
		endif
		//Now deal with 204 ratios if available
		if(Was204Measured == 1)
			Wave Raw_206_204=$MakeioliteWave("CurrentDRS","Raw_206_204",n=NoOfPoints)
			Raw_206_204 = Pb206_Beam/Pb204_Beam * MaskLowCPSBeam
			ListOfIntermediateChannels+="Raw_206_204;"
			if(waveexists(Pb207_Beam) == 1)
				Wave Raw_207_204=$MakeioliteWave("CurrentDRS","Raw_207_204",n=NoOfPoints)
				Raw_207_204 = Pb207_Beam/Pb204_Beam * MaskLowCPSBeam
				ListOfIntermediateChannels+="Raw_207_204;"
			endif
			if(waveexists(Pb208_Beam) == 1)
				Wave Raw_208_204=$MakeioliteWave("CurrentDRS","Raw_208_204",n=NoOfPoints)
				Raw_208_204 = Pb208_Beam/Pb204_Beam * MaskLowCPSBeam
				ListOfIntermediateChannels+="Raw_208_204;"
			endif
		endif
		//now want to add in a channel for U/Th ratio if both were measured (already know U238 was measured, so only need to check 232)
		if(waveexists(Th232_Beam) == 1)
			Wave Raw_U_Th_Ratio=$MakeioliteWave("CurrentDRS","Raw_U_Th_Ratio",n=NoOfPoints)
			Raw_U_Th_Ratio = (U238_Beam/1.0000)/(Th232_Beam/1.0000) * MaskLowCPSBeam		//currently using simple isotopic ratio here, can convert to elemental using 0.99275 (238U) and XXXXX (232Th)
			ListOfIntermediateChannels+="Raw_U_Th_Ratio;"
		endif
		//Now make the BeamSeconds wave (used as a proxy for hole depth during downhole fractionation correction)
		wave BeamSeconds=$DRS_MakeBeamSecondsWave(IndexOut,BeamSecondsSensitivity, BeamSecondsMethod) //This is determined by an external function which can be fine-tuned using the single sensitivity parameter.  Let me know if it fails!
		ListOfIntermediateChannels+="Beam_Seconds;"
		//up to this point no standard is required. Need to choose at least one standard integration at this point. (e.g. Z_91500)
		//Next, are we ready to proceed to producing the remaining outputs?
		DRSAbortIfNotSpline(StringFromList(0,ListOfIntermediateChannels), ReferenceStandard)
		//		//Have now checked that at least one Z_91500 has been selected, can proceed with the following, which is for down-hole fractionation correction
	
		SetProgress(30,"Starting down-hole curve fit...")	//Update progress for each channel

		//make a global to store the names of the ratios being fitted so that the pause for user code can use this information
		String/g $ioliteDFpath("CurrentDRS","ListOfFitWindows")
		SVar ListOfFitWindows = $ioliteDFpath("CurrentDRS","ListOfFitWindows")
		ListOfFitWindows = ""

		//the following lines are for the down-hole correction of ratios
		// JAP
		NVAR HoldDHC = root:Packages:VisualAge:Options:HoldDHC
		
	//Now make an SVar to hold a list of all parameters that need to be accessed by multiple functions (i.e., the function that follows curve fitting)
	String/g $ioliteDFpath("CurrentDRS","GeneralDRSParameters")
	SVar GeneralDRSParameters = $ioliteDFpath("CurrentDRS","GeneralDRSParameters")
	GeneralDRSParameters = ""
	GeneralDRSParameters += "NoOfPoints="+num2str(NoOfPoints) + ";"
	GeneralDRSParameters += "Was204Measured=" + num2str(Was204Measured) + ";"
	GeneralDRSParameters += "ShortCurveFitType=" + ShortCurveFitType + ";"		
		
		if(Calculate_208_232 == 1 && HoldDHC == 0)
			DownHoleCurveFit("Raw_208_232", OptionalWindowNumber = 0)	//the optional window number can be set, if it is it allows the function to stagger the windows so that they don't all overlap completely. if it's missing it defaults to 1
			ListOfFitWindows += "Win_"+"Raw_208_232"+"1" + ";"
		endif
		if(Calculate_207_235 == 1 && HoldDHC == 0)
			DownHoleCurveFit("Raw_207_235", OptionalWindowNumber = 1)	//the optional window number can be set, if it is it allows the function to stagger the windows so that they don't all overlap completely. if it's missing it defaults to 1
			ListOfFitWindows += "Win_"+"Raw_207_235"+"1" + ";"
		endif
		if(Calculate_206_238 == 1 && HoldDHC == 0)
			DownHoleCurveFit("Raw_206_238", OptionalWindowNumber = 2)	//the optional window number can be set, if it is it allows the function to stagger the windows so that they don't all overlap completely. if it's missing it defaults to 1
			ListOfFitWindows += "Win_"+"Raw_206_238"+"1" + ";"
		endif
		// !JAP
		//Note that the reverse order of the ratios here just means that the topmost graph is the most commonly used (i.e. 6/38 ratio)
		//NOTE: Although it may be confusing and is not a particularly nice solution, it is necessary to add waves to the list of intermediates and outputs here so that they won't be duplicated unnecessarily during a partial data crunch
		//This is an unnecessarily long list, but is done this way in order to produce the desired order for the output channels
		if(Calculate_207_235 == 1)
			ListOfIntermediateChannels+="DC207_235;"
			ListOfOutputChannels+="Final207_235;"
		endif
		if(Calculate_206_238 == 1)
			ListOfIntermediateChannels+="DC206_238;"
			ListOfOutputChannels+="Final206_238;"
		endif
		if(Calculate_207_206 == 1)
			ListOfIntermediateChannels+="DC207_206;"
			ListOfOutputChannels+="Final207_206;"
		endif
		if(Calculate_208_232 == 1)
			ListOfIntermediateChannels+="DC208_232;"
			ListOfOutputChannels+="Final208_232;"
		endif
		if(Calculate_206_208 == 1)
			ListOfIntermediateChannels+="DC206_208;"
			ListOfOutputChannels+="Final206_208;"
		endif
		if(Calculate_207_235 == 1)
			ListOfIntermediateChannels+="DCAge207_235;"
			ListOfOutputChannels+="FinalAge207_235;"
		endif
		if(Calculate_206_238 == 1)
			ListOfIntermediateChannels+="DCAge206_238;"
			ListOfOutputChannels+="FinalAge206_238;"
		endif
		if(Calculate_208_232 == 1)
			ListOfIntermediateChannels+="DCAge208_232;"
			ListOfOutputChannels+="FinalAge208_232;"
		endif
		if(Calculate_207_206 == 1)
			ListOfIntermediateChannels+="DCAge207_206;"
			ListOfOutputChannels+="FinalAge207_206;"
		endif
		if(Was204Measured == 1)		//if 204 was measured
			ListOfIntermediateChannels+="DC206_204;"
			ListOfOutputChannels+="Final206_204;"
			if(waveexists(Pb207_Beam) == 1)
				ListOfIntermediateChannels+="DC207_204;"
				ListOfOutputChannels+="Final207_204;"
			endif
			if(waveexists(Pb208_Beam) == 1)
				ListOfIntermediateChannels+="DC208_204;"
				ListOfOutputChannels+="Final208_204;"
			endif
		endif
		//now want to add in channels for U, Th, Pb abundances
		if(cmpstr(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
			ListOfOutputChannels+="Approx_U_PPM;"
		endif
		if(cmpstr(StringByKey("232", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
			ListOfOutputChannels+="Approx_Th_PPM;"
		endif
		if(cmpstr(StringByKey("208", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
			ListOfOutputChannels+="Approx_Pb_PPM;"
		endif
		if(cmpstr(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), "no") != 0 && cmpstr(StringByKey("232", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
			ListOfOutputChannels+="FInal_U_Th_Ratio;"
		endif
	//THIS IS A BIG ELSE. The following occurs if a 'partial' crunch data has been chosen. Any waves used below need to be referenced here
	else	
		//Allow all waves to be referenced, even if some don't exist
		Wave Raw_206_238=$ioliteDFpath("CurrentDRS","Raw_206_238")
		Wave Raw_207_235=$ioliteDFpath("CurrentDRS","Raw_207_235")
		Wave Raw_208_232=$ioliteDFpath("CurrentDRS","Raw_208_232")
		Wave Raw_207_206=$ioliteDFpath("CurrentDRS","Raw_207_206")
		Wave Raw_206_208=$ioliteDFpath("CurrentDRS","Raw_206_208")
		wave BeamSeconds=$ioliteDFpath("CurrentDRS", "Beam_Seconds")
	endif	//everything after here will be executed during both the 'partial' and normal data crunches
	OptionalPartialCrunch = 0	//Important: the first thing is to set the optional crunch back to the default of a full data crunch.
	if(Calculate_206_238 == 1)
		Wave DC206_238=$MakeioliteWave("CurrentDRS","DC206_238",n=NoOfPoints)
		Wave DCAge206_238=$MakeioliteWave("CurrentDRS","DCAge206_238",n=NoOfPoints)
	endif
	if(Calculate_207_235 == 1)
		Wave DC207_235=$MakeioliteWave("CurrentDRS","DC207_235",n=NoOfPoints)
		Wave DCAge207_235=$MakeioliteWave("CurrentDRS","DCAge207_235",n=NoOfPoints)
	endif
	if(Calculate_208_232 == 1)
		Wave DC208_232=$MakeioliteWave("CurrentDRS","DC208_232",n=NoOfPoints)
		Wave DCAge208_232=$MakeioliteWave("CurrentDRS","DCAge208_232",n=NoOfPoints)
	endif
	string CoefficientWaveName, ratio, SmoothWaveName, SplineWaveName, AverageBeamSecsName	//various strings required by the different fit types below
	strswitch(ShortCurveFitType)
		case "LinExp":
			if(Calculate_206_238 == 1)
				ratio = "Raw_206_238"
				CoefficientWaveName = "LECoeff_" + ratio
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				NVar Variable_b = $ioliteDFpath("CurrentDRS","LEVarB_"+ratio)	//variable b is the linear component of the equation
				DC206_238 = Raw_206_238 /  (1 + (Variable_b/Coefficients[0])*BeamSeconds + (Coefficients[1]/Coefficients[0])*Exp(-Coefficients[2]*BeamSeconds))
			endif
			if(Calculate_207_235 == 1)
				ratio = "Raw_207_235"
				CoefficientWaveName = "LECoeff_" + ratio
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				NVar Variable_b = $ioliteDFpath("CurrentDRS","LEVarB_"+ratio)	//variable b is the linear component of the equation
				DC207_235 = Raw_207_235 /  (1 + (Variable_b/Coefficients[0])*BeamSeconds + (Coefficients[1]/Coefficients[0])*Exp(-Coefficients[2]*BeamSeconds))
			endif
			if(Calculate_208_232 == 1)
				ratio = "Raw_208_232"
				CoefficientWaveName = "LECoeff_" + ratio
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				NVar Variable_b = $ioliteDFpath("CurrentDRS","LEVarB_"+ratio)	//variable b is the linear component of the equation
				DC208_232 = Raw_208_232 /  (1 + (Variable_b/Coefficients[0])*BeamSeconds + (Coefficients[1]/Coefficients[0])*Exp(-Coefficients[2]*BeamSeconds))
			endif
			break
		case "Exp":
			if(Calculate_206_238 == 1)
				CoefficientWaveName = "ExpCoeff_" + "Raw_206_238"
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				DC206_238 = Raw_206_238 /  (1+(Coefficients[1]/Coefficients[0])*Exp(-Coefficients[2]*BeamSeconds))//this equation is trying to change the magnitude of the original std wave to equal 1 at beamseconds = infinity, otherwise it will alter the ratios depending on the value obtained for the standard (could exploit this by factoring in a simultaneous drift correction?)
			endif
			if(Calculate_207_235 == 1)
				CoefficientWaveName = "ExpCoeff_" + "Raw_207_235"
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				DC207_235 = Raw_207_235 /  (1+(Coefficients[1]/Coefficients[0])*Exp(-Coefficients[2]*BeamSeconds))
			endif
			if(Calculate_208_232 == 1)
				CoefficientWaveName = "ExpCoeff_" + "Raw_208_232"
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				DC208_232 = Raw_208_232 /  (1+(Coefficients[1]/Coefficients[0])*Exp(-Coefficients[2]*BeamSeconds))
			endif
			break
		case "DblExp":
			if(Calculate_206_238 == 1)
				CoefficientWaveName = "DblExpCoeff_" + "Raw_206_238"
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				DC206_238 = Raw_206_238 /  (1 + (Coefficients[1]/Coefficients[0])*Exp(-Coefficients[2]*BeamSeconds) + (Coefficients[3]/Coefficients[0])*Exp(-Coefficients[4]*BeamSeconds))//this equation (y = K0+K1*exp(-K2*x)+K3*exp(-K4*x)) is trying to change the magnitude of the original std wave to equal 1 at beamseconds = infinity
			endif
			if(Calculate_207_235 == 1)
				CoefficientWaveName = "DblExpCoeff_" + "Raw_207_235"
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				DC207_235 = Raw_207_235 /  (1 + (Coefficients[1]/Coefficients[0])*Exp(-Coefficients[2]*BeamSeconds) + (Coefficients[3]/Coefficients[0])*Exp(-Coefficients[4]*BeamSeconds))//this equation (y = K0+K1*exp(-K2*x)+K3*exp(-K4*x)) is trying to change the magnitude of the original std wave to equal 1 at beamseconds = infinity
			endif
			if(Calculate_208_232 == 1)
				CoefficientWaveName = "DblExpCoeff_" + "Raw_208_232"
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				DC208_232 = Raw_208_232 /  (1 + (Coefficients[1]/Coefficients[0])*Exp(-Coefficients[2]*BeamSeconds) + (Coefficients[3]/Coefficients[0])*Exp(-Coefficients[4]*BeamSeconds))//this equation (y = K0+K1*exp(-K2*x)+K3*exp(-K4*x)) is trying to change the magnitude of the original std wave to equal 1 at beamseconds = infinity
			endif
			break
		case "Lin":
			if(Calculate_206_238 == 1)
				CoefficientWaveName = "LinCoeff_" + "Raw_206_238"
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				DC206_238 = Raw_206_238 /  (1+(Coefficients[1]/Coefficients[0])*BeamSeconds)//this equation is trying to change the magnitude of the original std wave to equal 1 at beamseconds = 0, otherwise it will alter the ratios depending on the value obtained for the standard (could exploit this by factoring in a simultaneous drift correction?)
			endif
			if(Calculate_207_235 == 1)
				CoefficientWaveName = "LinCoeff_" + "Raw_207_235"
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				DC207_235 = Raw_207_235 /  (1+(Coefficients[1]/Coefficients[0])*BeamSeconds)
			endif
			if(Calculate_208_232 == 1)
				CoefficientWaveName = "LinCoeff_" + "Raw_208_232"
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				DC208_232 = Raw_208_232 /  (1+(Coefficients[1]/Coefficients[0])*BeamSeconds)
			endif
			break
		case "RunMed":
			if(Calculate_206_238 == 1)
				ratio = "Raw_206_238"
				SmoothWaveName = "SmthFitCurve_"+Ratio
				wave SmoothedWave = $ioliteDFpath("CurrentDRS",SmoothWaveName)
				wave AverageBeamSeconds = $ioliteDFpath("CurrentDRS","AverageBeamSecs_"+ratio)
				DC206_238 = Raw_206_238 / ForInterp(Beamseconds, AverageBeamSeconds, SmoothedWave) * SmoothedWave[0]
			endif
			if(Calculate_207_235 == 1)
				ratio = "Raw_207_235"
				SmoothWaveName = "SmthFitCurve_"+Ratio
				wave SmoothedWave = $ioliteDFpath("CurrentDRS",SmoothWaveName)
				wave AverageBeamSeconds = $ioliteDFpath("CurrentDRS","AverageBeamSecs_"+ratio)
				DC207_235 = Raw_207_235 / ForInterp(Beamseconds, AverageBeamSeconds, SmoothedWave) * SmoothedWave[0]
			endif
			if(Calculate_208_232 == 1)
				ratio = "Raw_208_232"
				SmoothWaveName = "SmthFitCurve_"+Ratio
				wave SmoothedWave = $ioliteDFpath("CurrentDRS",SmoothWaveName)
				wave AverageBeamSeconds = $ioliteDFpath("CurrentDRS","AverageBeamSecs_"+ratio)
				DC208_232 = Raw_208_232 / ForInterp(Beamseconds, AverageBeamSeconds, SmoothedWave) * SmoothedWave[0]
			endif
			break
		case "Spline":
			if(Calculate_206_238 == 1)
				ratio = "Raw_206_238"
				SplineWaveName = "SplineCurve_"+Ratio
				wave SplineWave = $ioliteDFpath("CurrentDRS",SplineWaveName)
				wave SplineBeamSeconds = $ioliteDFpath("CurrentDRS","SplineBeamSecs_"+ratio)	//note that the spline method creates its own beamseconds wave that extends beyond averagebeamseconds
				DC206_238 = Raw_206_238 / ForInterp(Beamseconds, SplineBeamSeconds, SplineWave) * SplineWave[0]
			endif
			if(Calculate_207_235 == 1)
				ratio = "Raw_207_235"
				SplineWaveName = "SplineCurve_"+Ratio
				wave SplineWave = $ioliteDFpath("CurrentDRS",SplineWaveName)
				wave SplineBeamSeconds = $ioliteDFpath("CurrentDRS","SplineBeamSecs_"+ratio)
				DC207_235 = Raw_207_235 / ForInterp(Beamseconds, SplineBeamSeconds, SplineWave) * SplineWave[0]
			endif
			if(Calculate_208_232 == 1)
				ratio = "Raw_208_232"
				SplineWaveName = "SplineCurve_"+Ratio
				wave SplineWave = $ioliteDFpath("CurrentDRS",SplineWaveName)
				wave SplineBeamSeconds = $ioliteDFpath("CurrentDRS","SplineBeamSecs_"+ratio)
				DC208_232 = Raw_208_232 / ForInterp(Beamseconds, SplineBeamSeconds, SplineWave) * SplineWave[0]
			endif
			break
	endswitch
	if(Calculate_206_238 == 1)
		DCAge206_238 = Ln(DC206_238 + 1) / 0.000155125
		Wave Final206_238=$MakeioliteWave("CurrentDRS","Final206_238",n=NoOfPoints)
		Wave FinalAge206_238=$MakeioliteWave("CurrentDRS","FinalAge206_238",n=NoOfPoints)
	endif
	if(Calculate_207_235 == 1)
		DCAge207_235 = Ln((DC207_235) + 1) / 0.00098485
		Wave Final207_235=$MakeioliteWave("CurrentDRS","Final207_235",n=NoOfPoints)
		Wave FinalAge207_235=$MakeioliteWave("CurrentDRS","FinalAge207_235",n=NoOfPoints)
	endif
	if(Calculate_208_232 == 1)
		DCAge208_232 = Ln(DC208_232 + 1) / 0.000049475
		Wave Final208_232=$MakeioliteWave("CurrentDRS","Final208_232",n=NoOfPoints)
		Wave FinalAge208_232=$MakeioliteWave("CurrentDRS","FinalAge208_232",n=NoOfPoints)
	endif
	//at the moment I don't think Pb-Pb ratios need any treatment, so they are left as they were...
	if(Calculate_207_206 == 1)
		Wave DC207_206=$MakeioliteWave("CurrentDRS","DC207_206",n=NoOfPoints)
		Wave DCAge207_206=$MakeioliteWave("CurrentDRS","DCAge207_206",n=NoOfPoints)
		DC207_206 = Raw_207_206
		wave LookupTable_76 = $ioliteDFpath("CurrentDRS","LookupTable_76")
		wave LookupTable_age = $ioliteDFpath("CurrentDRS","LookupTable_age")
		DCAge207_206 = interp(DC207_206, LookupTable_76, LookupTable_age)
		Wave Final207_206=$MakeioliteWave("CurrentDRS","Final207_206",n=NoOfPoints)
		Wave FinalAge207_206=$MakeioliteWave("CurrentDRS","FinalAge207_206",n=NoOfPoints)
	endif
	if(Calculate_206_208 == 1)
		Wave DC206_208=$MakeioliteWave("CurrentDRS","DC206_208",n=NoOfPoints)
		DC206_208 = Raw_206_208
		Wave Final206_208=$MakeioliteWave("CurrentDRS","Final206_208",n=NoOfPoints)
	endif
	if(Was204Measured == 1)		//if 204 was measured
		Wave DC206_204=$MakeioliteWave("CurrentDRS","DC206_204",n=NoOfPoints)
		DC206_204 = Raw_206_204
		Wave Final206_204=$MakeioliteWave("CurrentDRS","Final206_204",n=NoOfPoints)
		if(waveexists(Pb207_Beam) == 1)
			Wave DC207_204=$MakeioliteWave("CurrentDRS","DC207_204",n=NoOfPoints)
			DC207_204 = Raw_207_204
			Wave Final207_204=$MakeioliteWave("CurrentDRS","Final207_204",n=NoOfPoints)
		endif
		if(waveexists(Pb208_Beam) == 1)
			Wave DC208_204=$MakeioliteWave("CurrentDRS","DC208_204",n=NoOfPoints)
			DC208_204 = Raw_208_204
			Wave Final208_204=$MakeioliteWave("CurrentDRS","Final208_204",n=NoOfPoints)
		endif
	endif
	
	SetProgress(40,"Calculating final ratios...")	//Update progress for each channel
	
	//so, have done down-hole correction, now need to do drift correction (note that there is often a substantial offset in raw and down hole corr. values from true values)		
	//(relevant waves were already made above in the if statements)
	//and make some waves for the approximated elemental concentrations
	//now want to add in a channel for U, Th, Pb abundances
	if(cmpstr(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
		Wave Approx_U_PPM=$MakeioliteWave("CurrentDRS","Approx_U_PPM",n=NoOfPoints)
	endif
	if(cmpstr(StringByKey("232", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
		Wave Approx_Th_PPM=$MakeioliteWave("CurrentDRS","Approx_Th_PPM",n=NoOfPoints)
	endif
	if(cmpstr(StringByKey("208", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
		Wave Approx_Pb_PPM=$MakeioliteWave("CurrentDRS","Approx_Pb_PPM",n=NoOfPoints)
	endif
	if(cmpstr(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), "no") != 0 && cmpstr(StringByKey("232", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
		Wave FInal_U_Th_Ratio=$MakeioliteWave("CurrentDRS","FInal_U_Th_Ratio",n=NoOfPoints)
	endif
	//now call an external function to do the actual drift correction. The reason for using an external function is that it's also called during export for error propagation.
	DriftCorrectRatios()		//this function has optional range parameters, but they can be left blank and the function will operate on the entire wave
	//replacing the original error propagation with the below generic version (no blossoming of errors with low N integrations)
	//propagate each ratio separately, using the relevant down-hole corrected ratio
	
	//############################################################
	// JAP	
	
	// Get rid of old waves:
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalDiscPercent")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAnd207_235")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAnd206_238")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAnd208_232")	
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAgeAnd207_206")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalFracCommonPb")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalFracLostPb")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "AndersenDeltaAge")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "AndersenSolution")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAgeAnd206_238")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAgeAnd207_235")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAgeAnd208_232")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "Final238_206")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAnd238_206")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAnd207_206")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalPbC206_238")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalPbC207_235")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalPbC208_232")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalPbC238_206")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalPbC207_206")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAgePbC206_238")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAgePbC207_235")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAgePbC208_232")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAgePbC207_206")

	// Remove everything from the output list (they'll be added back later):
	ListOfOutputChannels = RemoveFromList("Final238_206;FinalAnd238_206;FinalAnd207_206;", ListOfOutputChannels)
	ListOfOutputChannels = RemoveFromList("FinalAnd207_235;FinalAnd206_238;", ListOfOutputChannels)
	ListOfOutputChannels = RemoveFromList("FinalAnd208_232;FinalAgeAnd207_206;FinalAgeAnd206_238;", ListOfOutputChannels)
	ListOfOutputChannels = RemoveFromList("FinalAgeAnd207_235;FinalAgeAnd208_232;FinalFracCommonPb;", ListOfOutputChannels)
	ListOfOutputChannels = RemoveFromList("FinalFracLostPb;AndersenSolution;FinalDiscPercent;", ListOfOutputChannels)
	ListOfOutputChannels = RemoveFromList("FinalPbC206_238;FinalPbC207_235;FinalPbC208_232;FinalPbC207_206;FinalPbC238_206;", ListOfOutputChannels)
	ListOfOutputChannels = RemoveFromList("FinalAgePbC206_238;FinalAgePbC207_235;FinalAgePbC208_232;FinalAgePbC207_206;", ListOfOutputChannels)
	
	NVAR doPbPb = root:Packages:VisualAge:Options:PbPbOption_Calculate	
	NVAR doAndersen = root:Packages:VisualAge:Options:AndersenOption_Calculate	
	NVAR do204 = root:Packages:VisualAge:Options:PbCOption_Calculate
	NVAR Have204 = root:Packages:VisualAge:Was204Measured
	
	Have204 = Was204Measured

	// Make the required waves:
	Wave Final238_206=$MakeioliteWave("CurrentDRS", "Final238_206", n=NoOfPoints)
	Wave FinalDiscPercent=$MakeioliteWave("CurrentDRS", "FinalDiscPercent", n = NoOfPoints)	
	
	If (doPbPb)
		Killwaves/Z $ioliteDFpath("CurrentDRS", "FinalAge207_206")
		ListOfOutputChannels = RemoveFromList("FinalAge207_206;", ListOfOutputChannels)
		Wave FinalAge207_206=$MakeioliteWave("CurrentDRS", "FinalAge207_206", n = NoOfPoints)	
	EndIf
	
	If (doAndersen)
		Wave FinalAnd207_235=$MakeioliteWave("CurrentDRS", "FinalAnd207_235", n = NoOfPoints)
		Wave FinalAnd206_238=$MakeioliteWave("CurrentDRS", "FinalAnd206_238", n = NoOfPoints)
		Wave FinalAnd208_232=$MakeioliteWave("CurrentDRS", "FinalAnd208_232", n = NoOfPoints)
		Wave FinalAnd238_206=$MakeioliteWave("CurrentDRS", "FinalAnd238_206", n=NoOfPoints)
		Wave FinalAnd207_206=$MakeioliteWave("CurrentDRS", "FinalAnd207_206", n=NoOfPoints)

		Wave FinalAgeAnd207_206=$MakeioliteWave("CurrentDRS", "FinalAgeAnd207_206", n = NoOfPoints)
		Wave FinalAgeAnd206_238=$MakeioliteWave("CurrentDRS", "FinalAgeAnd206_238", n = NoOfPoints)
		Wave FinalAgeAnd207_235=$MakeioliteWave("CurrentDRS", "FinalAgeAnd207_235", n = NoOfPoints)
		Wave FinalAgeAnd208_232=$MakeioliteWave("CurrentDRS", "FinalAgeAnd208_232", n = NoOfPoints)

		Wave FinalFracCommonPb=$MakeioliteWave("CurrentDRS", "FinalFracCommonPb", n = NoOfPoints)
		Wave FinalFracLostPb=$MakeioliteWave("CurrentDRS", "FinalFracLostPb", n = NoOfPoints)
		Wave AndersenDeltaAge=$MakeioliteWave("CurrentDRS", "AndersenDeltaAge", n = NoOfPoints)
		Wave AndersenSolution=$MakeioliteWave("CurrentDRS", "AndersenSolution", n = NoOfPoints)
	EndIf
	
	If (do204 && Was204Measured)
		Wave FinalPbC206_238=$MakeioliteWave("CurrentDRS", "FinalPbC206_238", n = NoOfPoints)
		Wave FinalPbC207_235=$MakeioliteWave("CurrentDRS", "FinalPbC207_235", n = NoOfPoints)
		Wave FinalPbC208_232=$MakeioliteWave("CurrentDRS", "FinalPbC208_232", n = NoOfPoints)
		Wave FinalPbC238_206=$MakeioliteWave("CurrentDRS", "FinalPbC238_206", n = NoOfPoints)
		Wave FinalPbC207_206=$MakeioliteWave("CurrentDRS", "FinalPbC207_206", n = NoOfPoints)
		Wave FinalAgePbC206_238=$MakeioliteWave("CurrentDRS", "FinalAgePbC206_238", n = NoOfPoints)
		Wave FinalAgePbC207_235=$MakeioliteWave("CurrentDRS", "FinalAgePbC207_235", n = NoOfPoints)
		Wave FinalAgePbC208_232=$MakeioliteWave("CurrentDRS", "FinalAgePbC208_232", n = NoOfPoints)
		Wave FinalAgePbC207_206=$MakeioliteWave("CurrentDRS", "FinalAgePbC207_206", n = NoOfPoints)		
	EndIf
	
	// Calculate the 38/06 ratio:
	ListOfOutputChannels += "Final238_206;"
	Final238_206 = 1/Final206_238
	
	// Do 7/6 age calculation if desired:
	If (doPbPb)
		SetProgress(50, "Calculating 207Pb/206Pb ages")
	
		ListOfOutputChannels += "FinalAge207_206;"
		PbPbAges()
	EndIf
	
	// Calculate a rough measure of discordance:
	ListOfOutputChannels += "FinalDiscPercent;"
	SetProgress(60, "Calculating degree of discordance")
	CalculateDisc()
	CalculateDose()
	
	// Do Andersen correction if desired:
	If (doAndersen)
		ListOfOutputChannels += "FinalAnd207_235;FinalAnd206_238;FinalAnd208_232;FinalAnd238_206;FinalAnd207_206;"
		ListOfOutputChannels += "FinalAgeAnd207_206;FinalAgeAnd207_235;FinalAgeAnd206_238;FinalAgeAnd208_232;"
		ListOfOutputChannels += "FinalFracCommonPb;FinalFracLostPb;AndersenSolution;"
		
		// Then iterate Andersen routine until ages don't change:
		NVAR reAndersen = root:Packages:VisualAge:RecrunchAndersen
		NVAR maxAndersenItrs = root:Packages:VisualAge:Options:AndersenOption_MaxRecalc
	
		SetProgress(70, "Doing Andersen's common-Pb correction")
	
		Print "[VisualAge] Andersen routine will execute " + num2str(maxAndersenItrs) + " times or less."
	
		Variable numAndersenItrs = 0
	
		AndersenDeltaAge = -1
		AndersenSolution = 0
		Do
			Print "[VisualAge] Starting Andersen iteration " + num2str (numAndersenItrs + 1) + "."
			Andersen()
			numAndersenItrs = numAndersenItrs + 1
		While ( reAndersen && numAndersenItrs < maxAndersenItrs )
		
		FinalAnd238_206 = 1/FinalAnd206_238
		Variable j
		For (j = 0; j < NoOfPoints; j = j + 1)
			FinalAnd207_206[j] = Ratio7_6(FinalAgeAnd207_206[j]*1e6)
		EndFor
	EndIf
	
	// Do 204Pb common Pb correction if desired:
	If (do204 && Was204Measured)
		ListOfOutputChannels += "FinalPbC207_235;FinalPbC206_238;FinalPbC208_232;FinalPbC207_206;FinalPbC238_206;"
		ListOfOutputChannels += "FinalAgePbC207_206;FinalAgePbC207_235;FinalAgePbC206_238;FinalAgePbC208_232;"
		
		SetProgress(80, "Doing 204Pb common-Pb correction")
		
		Calculate204PbCorrection()
	EndIf
		
	// !JAP
	//############################################################
	
	
	SetProgress(90,"Propagating errors...")	//Update progress for each channel
	
	string ListOfOutputsToPropagate
	if(Calculate_206_238 == 1)
		ListOfOutputsToPropagate = "Final206_238;FinalAge206_238"
		Propagate_Errors("All", ListOfOutputsToPropagate, "DC206_238", ReferenceStandard)
	endif
	if(Calculate_207_235 == 1)
		ListOfOutputsToPropagate = "Final207_235;FinalAge207_235"
		Propagate_Errors("All", ListOfOutputsToPropagate, "DC207_235", ReferenceStandard)
	endif
	if(Calculate_208_232 == 1)
		ListOfOutputsToPropagate = "Final208_232;FinalAge208_232"
		Propagate_Errors("All", ListOfOutputsToPropagate, "DC208_232", ReferenceStandard)
	endif
	if(Calculate_207_206 == 1)
		ListOfOutputsToPropagate = "Final207_206;FinalAge207_206"
		Propagate_Errors("All", ListOfOutputsToPropagate, "DC207_206", ReferenceStandard)
	endif
	if(Calculate_206_208 == 1)
		ListOfOutputsToPropagate = "Final206_208"
		Propagate_Errors("All", ListOfOutputsToPropagate, "DC206_208", ReferenceStandard)
	endif
	
	If (doAndersen)
		if (Calculate_206_238 == 1)
			ListOfOutputsToPropagate = "FinalAnd206_238;FinalAgeAnd206_238"
			Propagate_Errors("All", ListOfOutputsToPropagate, "DC206_238", ReferenceStandard)
		endif

		if (Calculate_207_235 == 1)		
			ListOfOutputsToPropagate = "FinalAnd207_235;FinalAgeAnd207_235"
			Propagate_Errors("All", ListOfOutputsToPropagate, "DC207_235", ReferenceStandard)
		endif
		
		if (Calculate_208_232 == 1)
			ListOfOutputsToPropagate = "FinalAnd208_232;FinalAgeAnd208_232"
			Propagate_Errors("All", ListOfOutputsToPropagate, "DC208_232", ReferenceStandard)		
		endif
		
		if (Calculate_207_206 == 1)
			ListOfOutputsToPropagate = "FinalAnd207_206;FinalAgeAnd207_206"
			Propagate_Errors("All", ListOfOutputsToPropagate, "DC207_206", ReferenceStandard)
		endif
	EndIf
	
	if (do204 && Was204Measured)
		if (Calculate_206_238 == 1)
			ListOfOutputsToPropagate = "FinalPbC206_238;FinalAgePbC206_238"
			Propagate_Errors("All", ListOfOutputsToPropagate, "DC206_238", ReferenceStandard)
		endif

		if (Calculate_207_235 == 1)		
			ListOfOutputsToPropagate = "FinalPbC207_235;FinalAgePbC207_235"
			Propagate_Errors("All", ListOfOutputsToPropagate, "DC207_235", ReferenceStandard)
		endif
		
		if (Calculate_208_232 == 1)
			ListOfOutputsToPropagate = "FinalPbC208_232;FinalAgePbC208_232"
			Propagate_Errors("All", ListOfOutputsToPropagate, "DC208_232", ReferenceStandard)		
		endif
		
		if (Calculate_207_206 == 1)
			ListOfOutputsToPropagate = "FinalPbC207_206;FinalAgePbC207_206"
			Propagate_Errors("All", ListOfOutputsToPropagate, "DC207_206", ReferenceStandard)
		endif	
	endif

	SetProgress(100,"Finished DRS.")	//Update progress for each channel

end   //****End of DRS function.  Write any required external sub-routines below this point****




//############################################################
// JAP

//------------------------------------------------------------------------
// Calculates discordance of each point
//------------------------------------------------------------------------
Function CalculateDisc()
	
	Wave FinalDiscPercent=$ioliteDFpath("CurrentDRS", "FinalDiscPercent")
	
	Wave Final207_235=$ioliteDFpath("CurrentDRS", "Final207_235")
	Wave Final206_238=$ioliteDFpath("CurrentDRS", "Final206_238")
	
	Wave FinalAge206_238=$ioliteDFpath("CurrentDRS", "FinalAge206_238")
	Wave FinalAge207_206=$ioliteDFpath("CurrentDRS", "FinalAge207_206")
		
	Variable Npts = numpnts(FinalDiscPercent)
	
	Variable i
	For( i = 0; i < Npts; i = i + 1 )
		//FinalDiscPercent[i] = DiscPercent(Final207_235[i], Final206_238[i])
		FinalDiscPercent[i] = DiscPercent2(FinalAge206_238[i], FinalAge207_206[i])
	EndFor		
End

//------------------------------------------------------------------------
// Calculates the 207/206 age of each point
//------------------------------------------------------------------------
Function PbPbAges()
	Print "[VisualAge] Starting calculation of 207Pb/206Pb ages."

	// Get time for calculation start:
	Variable calcStartTime = DateTime

	// Get required waves from iolite:
	Wave Final207_206=$ioliteDFpath("CurrentDRS", "Final207_206")
	Wave FinalAge207_235=$ioliteDFpath("CurrentDRS", "FinalAge207_235")
	Wave FinalAge206_238=$ioliteDFpath("CurrentDRS", "FinalAge206_238")
	Wave FinalAge207_206=$ioliteDFpath("CurrentDRS", "FinalAge207_206")
	
	// Get number of wave points:
	Variable Npts = numpnts(FinalAge207_206)

	SVAR wavesForGuess = root:Packages:VisualAge:Options:PbPbOption_WavesForGuess
	
	// Loop through each point, and call the PbPb routine for each:
	Variable i
	For ( i = 1; i < Npts; i = i + 1 )
		
		// Get current 7/6 ratio:
		Variable m = (Final207_206[i] + Final207_206[i-1] + Final207_206[i+1])/3
		
		// Calculate a reasonable guess at the age:
		Variable guess = 1e6*(AgeFromList(wavesForGuess, i))
		
		// If the ratio or age seem unreasonable set age to NaN and skip
		If (numtype(m) == 2 || guess <= 1 || guess > 5e9 || numtype(guess) == 2)
			FinalAge207_206[i] = NaN
			Continue
		EndIf
		
		// Call Newton's method PbPb function:
		FinalAge207_206[i] = CalculatePbPbAge(m, guess)
	
	EndFor

	// Get time of completion:
	Variable calcStopTime = DateTime

	// Spit out some info:
	Print "[VisualAge] ...Done. Calculation duration: " + num2str(calcStopTime - calcStartTime) + " s."
End

//------------------------------------------------------------------------
// Calculates 204Pb corrections for each point
//------------------------------------------------------------------------
Function Calculate204PbCorrection()

	Variable calcStartTime = DateTime
	Print "[VisualAge] Starting 204Pb correction."
	
	Wave Final207_204 = $ioliteDFpath("CurrentDRS", "Final207_204")
	Wave Final206_204 = $ioliteDFpath("CurrentDRS", "Final206_204")
	Wave Final208_204 = $ioliteDFpath("CurrentDRS", "Final208_204")
	Wave Final207_206 = $ioliteDFpath("CurrentDRS", "Final207_206")
	Wave FinalAge206_238 = $ioliteDFpath("CurrentDRS", "FinalAge206_238")
	Wave FinalAge207_206 = $ioliteDFpath("CurrentDRS", "FinalAge207_206")
	Wave FinalPbC206_238 = $ioliteDFpath("CurrentDRS", "FinalPbC206_238")
	Wave FinalPbC238_206 = $ioliteDFpath("CurrentDRS", "FinalPbC238_206")	
	Wave FinalPbC207_235 = $ioliteDFpath("CurrentDRS", "FinalPbC207_235")
	Wave FinalPbC208_232 = $ioliteDFpath("CurrentDRS", "FinalPbC208_232")
	Wave FinalPbC207_206 = $ioliteDFpath("CurrentDRS", "FinalPbC207_206")
	Wave Final207_235 = $ioliteDFpath("CurrentDRS", "Final207_235")
	Wave Final206_238 = $ioliteDFpath("CurrentDRS", "Final206_238")
	Wave Final208_232 = $ioliteDFpath("CurrentDRS", "Final208_232")
	Wave FinalAgePbC207_235 = $ioliteDFpath("CurrentDRS", "FinalAgePbC207_235")
	Wave FinalAgePbC206_238 = $ioliteDFpath("CurrentDRS", "FinalAgePbC206_238")
	Wave FinalAgePbC208_232 = $ioliteDFpath("CurrentDRS", "FinalAgePbC208_232")
	Wave FinalAgePbC207_206 = $ioliteDFpath("CurrentDRS", "FinalAgePbC207_206")
	
	SVAR WavesForGuess = root:Packages:VisualAge:Options:PbCOption_WavesForGuess
	NVAR UsePbComp = root:Packages:VisualAge:Options:Option_UsePbComp
	NVAR Pb64 = root:Packages:VisualAge:Options:Option_Common64
	NVAR Pb74 = root:Packages:VisualAge:Options:Option_Common74
	NVAR Pb84 = root:Packages:VisualAge:Options:Option_Common84		
	NVAR k = root:Packages:VisualAge:Constants:k
	
	Variable Npts = numpnts(FinalAge206_238)	
	Variable common64, common74, common84	
	
	Variable i
	For (i = 0; i < Npts; i = i + 1)
		Variable cAge = AgeFromList(WavesForGuess, i)
		If (numtype(cAge) == 2)
			FinalPbC207_235[i] = NaN
			FinalPbC206_238[i] = NaN
			FinalPbC208_232[i] = NaN
			FinalAgePbC207_235[i] = NaN
			FinalAgePbC206_238[i] = NaN
			FInalAgePbC208_232[i] = NaN
			FinalAgePbC207_206[i] = NaN
			Continue
		EndIf
		
		If (UsePbComp)
			common64 = Pb64
			common74 = Pb74
			common84 = Pb84
		Else
			common64 = 0.023*(cAge/1e3)^3 - 0.359*(cAge/1e3)^2 - 1.008*(cAge/1e3) + 19.04
			common74 = -0.034*(cAge/1e3)^4 +0.181*(cAge/1e3)^3 - 0.448*(cAge/1e3)^2 + 0.334*(cAge/1e3) + 15.64	
			common84 = -2.200*(cAge/1e3) + 39.47
		EndIf
		
		FinalPbC207_235[i] = Final207_235[i]*(Final207_204[i] - common74)/(Final207_204[i])
		FinalPbC206_238[i] = Final206_238[i]*(Final206_204[i] - common64)/(Final206_204[i])
		FinalPbC208_232[i] = Final208_232[i]*(Final208_204[i] - common84)/(Final208_204[i])
		FinalPbC207_206[i] = (Final206_204[i]*Final207_206[i] - common74)/(Final206_204[i] - common64)
	
		FinalAgePbC207_235[i] = 1e-6*Age7_35(FinalPbC207_235[i])
		FinalAgePbC206_238[i] = 1e-6*Age6_38(FinalPbC206_238[i])
		FinalAgePbC208_232[i] = 1e-6*Age8_32(FinalPbC208_232[i])
		
		Variable guess = 1e6*(AgeFromList(WavesForGuess, i))
		FinalAgePbC207_206[i] = CalculatePbPbAge( FinalPbC207_206[i], guess) 
		
		//Variable guess = 1e6*(AgeFromList(WavesForGuess, i))		
		//FinalAgePbC207_206[i] = CalculatePbPbAge( (1/k)*FinalPbC207_235[i]/FInalPbC206_238[i], guess)
		//FinalPbC207_206[i] = Ratio7_6(1e6*FinalAgePbC207_206[i])
	
	EndFor
	
	FinalPbC238_206 = 1/FinalPbC206_238
	
	// Get time of completion:
	Variable calcStopTime = DateTime

	// Spit out some info:
	Print "[VisualAge] ...Done. Calculation duration: " + num2str(calcStopTime - calcStartTime) + " s."	
End

//------------------------------------------------------------------------
// Calculates the Andersen corrections for each point
//------------------------------------------------------------------------
Function Andersen()

	// Get calculation start time:
	Variable calcStartTime = DateTime

	Wave FinalDiscPercent=$ioliteDFpath("CurrentDRS", "FinalDiscPercent")

	// Get ratios computed by iolite:
	Wave Final207_235=$ioliteDFpath("CurrentDRS", "Final207_235")
	Wave Final206_238=$ioliteDFpath("CurrentDRS", "Final206_238")
	Wave Final208_232=$ioliteDFpath("CurrentDRS", "Final208_232")
	Wave Final207_206=$ioliteDFpath("CurrentDRS", "Final207_206")
	Wave Final_U_Th_Ratio=$ioliteDFpath("CurrentDRS", "Final_U_Th_Ratio")

	// Get ages computed by iolite + PbPbAges:
	Wave FinalAge207_206=$ioliteDFpath("CurrentDRS", "FinalAge207_206")
	Wave FinalAge207_235=$ioliteDFpath("CurrentDRS", "FinalAge207_235")
	Wave FinalAge206_238=$ioliteDFpath("CurrentDRS", "FinalAge206_238")
	Wave FinalAge208_232=$ioliteDFpath("CurrentDRS", "FinalAge208_232")

	// Get waves for Andersen routine:
	Wave FinalAgeAnd207_206=$ioliteDFpath("CurrentDRS", "FinalAgeAnd207_206")
	Wave AndersenDeltaAge=$ioliteDFpath("CurrentDRS", "AndersenDeltaAge")
	Wave FinalFracCommonPb=$ioliteDFpath("CurrentDRS", "FinalFracCommonPb")
	Wave FinalFracLostPb=$ioliteDFpath("CurrentDRS", "FinalFracLostPb")
	Wave AndersenSolution=$ioliteDFpath("CurrentDRS", "AndersenSolution")
	Wave FinalAnd207_235=$ioliteDFpath("CurrentDRS", "FinalAnd207_235")
	Wave FinalAnd206_238=$ioliteDFpath("CurrentDRS", "FinalAnd206_238")
	Wave FinalAnd208_232=$ioliteDFpath("CurrentDRS", "FinalAnd208_232")
	Wave FinalAgeAnd206_238=$ioliteDFpath("CurrentDRS", "FinalAgeAnd206_238")
	Wave FinalAgeAnd207_235=$ioliteDFpath("CurrentDRS", "FinalAgeAnd207_235")
	Wave FinalAgeAnd208_232=$ioliteDFpath("CurrentDRS", "FinalAgeAnd208_232")
	
	Variable Npts = numpnts(FinalAgeAnd207_206)	
		
	// Make duplicates of the needed ratios:
	Duplicate/O Final207_235, xw
	Duplicate/O Final206_238, yw
	Duplicate/O Final208_232, zw
	Duplicate/O Final_U_Th_Ratio, uw
	
	Make/O/N=(Npts) StartingAges

	// Define iteration parameters:
	Variable itrNum = 0
	SVAR ageList = root:Packages:VisualAge:Options:AndersenOption_WavesForGuess
	NVAR numMaxItr = root:Packages:VisualAge:Options:AndersenOption_MaxIters
	NVAR eps = root:Packages:VisualAge:Options:AndersenOption_Epsilon
	NVAR reAndersen = root:Packages:VisualAge:RecrunchAndersen
	NVAR t2 = root:Packages:VisualAge:Options:AndersenOption_t2
	reAndersen = 0
	
	// Decay constants:
	NVAR l235 = root:Packages:VisualAge:Constants:l235
	NVAR l238 = root:Packages:VisualAge:Constants:l238
	NVAR l232 = root:Packages:VisualAge:Constants:l232
	
	// Define present-day 238U/235U:
	NVAR k = root:Packages:VisualAge:Constants:k
	
	Variable c7, c8 // Common Pb composition
	Variable ct1, nt1 // Current and "new" value for t1
	Variable xt1, yt1, zt1 // U-Pb and Th-Pb ratios at t1
	Variable dxt1, dyt1, dzt1 // Derivative of ratios wrt t1
	Variable xt2, yt2, zt2 // U-Pb and Th-Pb ratios at t2 (age of Pb loss)
	
	Variable i
	For ( i=0; i<Npts; i=i+1) // Main loop
		itrNum = 0	
		
		// If age hasn't changed, skip:
		If (AndersenDeltaAge[i] == 0 || numtype(AndersenDeltaAge[i]) == 2)
			Continue
		EndIf
			
		If (AndersenDeltaAge[i] > 0 )  
			// If Andersen's t1 has already been calculated, use it as the guess:
			ct1 = FinalAgeAnd207_206[i]*1e6
		Else
			// Otherwise, use a guess at the age and if it is young, don't bother with the 7/35 or 7/6 age:
			If ( Final207_206[i] > 0.5 )
				ct1 = AgeFromList(ageList, i)*1e6	
			Else
				ct1 = AgeFromList(RemoveFromList("FinalAge207_235;FinalAge207_206;", ageList), i)*1e6
			EndIf
		EndIf
		
		// Set the starting ages:
		StartingAges[i] = ct1
		nt1 = ct1

		// Calculate starting values for ratios:
		xt1 = exp(l235*ct1) -1
		yt1 = exp(l238*ct1) -1
		zt1 = exp(l232*ct1) -1
			
		xt2 = exp(l235*t2) - 1
		yt2 = exp(l238*t2) - 1
		zt2 = exp(l232*t2) - 1
		
		// Initialize function + derivative:
		Variable ft = 0, dft = 0
		Variable A1, B1, C1, D1
		
		// Initialize common Pb stuff:
		Variable common64, common74, common84
		Variable Gct1 = ct1/1e9
		
		NVAR usePbComp = root:Packages:VisualAge:Option_UsePbComp
		
		If ( usePbComp )
			// Use common Pb composition specified in DRS options:
			NVAR c64 = root:Packages:VisualAge:Options:Option_Common64
			NVAR c74 = root:Packages:VisualAge:Options:Option_Common74
			NVAR c84 = root:Packages:VisualAge:Options:Option_Common84
			
			common64 = c64
			common74 = c74
			common84 = c84
		Else
			// Compute c7 and c8 using BSK's fits:
			common64 = 0.023*(Gct1)^3 - 0.359*(Gct1)^2 - 1.008*(Gct1) + 19.04
			common74 = -0.034*(Gct1)^4 +0.181*(Gct1)^3 - 0.448*(Gct1)^2 + 0.334*(Gct1) + 15.64
			common84 = -2.200*(Gct1) + 39.47
		EndIf

		c7 = common74/common64
		c8 = common84/common64
					
		// Determine if point is roughly concordant, if so: skip
		NVAR discCutOff = root:Packages:VisualAge:Options:AndersenOption_OnlyGTDisc

		If ( FinalDiscPercent[i] < discCutOff)
			AndersenSolution[i] = 0.5
			AndersenDeltaAge[i] = 0
			FinalAgeAnd207_206[i] = FinalAge207_206[i]
			FinalAnd206_238[i] = Final206_238[i]
			FinalAnd207_235[i] = Final207_235[i]
			FinalAnd208_232[i] = Final208_232[i]
			FinalFracCommonPb[i] = 0
			FinalFracLostPb[i] = 0
			Continue
		EndIf

		// Newton's method to find Andersen's t1:
		Do 			
			ct1 = nt1	
			
			xt1 = exp(l235*ct1) -1
			yt1 = exp(l238*ct1) -1
			zt1 = exp(l232*ct1) -1
		
			dxt1 = l235*exp(l235*ct1)
			dyt1 = l238*exp(l238*ct1)
			dzt1 = l232*exp(l232*ct1)			
			
			// Andersen's version:
			A1 = (yw[i]*(xt1-xt2) - yt2*xt1 + xw[i]*(yt2-yt1) + xt2*yt1)*yw[i]
			B1 = (zt1-zt2-c8*uw[i]*yt1+c8*uw[i]*yt2)
			C1 = (zw[i]*(yt2-yt1) + zt2*yt1 + yw[i]*(zt1-zt2) -yt2*zt1)*yw[i]
			D1 = (xt1-xt2 -c7*k*yt1 + c7*k*yt2)
			ft = A1*B1 - C1*D1
			dft = A1*(dzt1 - c8*uw[i]*dyt1) + B1*yw[i]*(yw[i]*dxt1 - yt2*dxt1 - xw[i]*dyt1 + xt2*dyt1) - C1*(dxt1-c7*k*dyt1) - D1*yw[i]*(-zw[i]*dyt1+zt2*dyt1 + yw[i]*dzt1 -yt2*dzt1)
			
			// Another version:
			//A1 = (yw[i]*(xt1-xt2) - yt2*xt1 + xw[i]*(yt2-yt1) + xt2*yt1)
			//B1 = (zt1-zt2-c8*uw[i]*yt1+c8*uw[i]*yt2)
			//C1 = (zw[i]*(yt2-yt1) + zt2*yt1 + yw[i]*(zt1-zt2) -yt2*zt1)
			//D1 = (xt1-xt2 -c7*k*yt1 + c7*k*yt2)
			//ft = (A1/D1) - (C1/B1)
			//dft = (1/D1)*(yw[i]*dxt1 - yt2*dxt1 - xw[i]*dyt1 + xt2*dyt1) - (A1/(D1*D1))*(dxt1-c7*k*dyt1) - (1/B1)*(-zw[i]*dyt1+zt2*dyt1 + yw[i]*dzt1 -yt2*dzt1) + (C1/(B1*B1))*(dzt1 - c8*uw[i]*dyt1)
			
			nt1 = ct1 - ft/dft
			itrNum = itrNum + 1
	
		While ( abs(ft) > eps && itrNum < numMaxItr )
		// End of Newton's method
		
		// Check if value makes sense:
		If (nt1 > 4.5e9 || nt1 < 1e6 || numtype(nt1) == 2 )
			// If no solution is found, set age to not a number or last known age (not sure which is better?)
			nt1 = StartingAges[i]//NaN
			
			// Keep track of whether or not a valid solution was found:
			AndersenSolution[i] = 0
		Else
			AndersenSolution[i] = 1
		EndIf
		
		// Store final age in Ma:
		FinalAgeAnd207_206[i] = nt1/1e6
		
		// Compute the delta age and set reAndersen if large enough delta:
		AndersenDeltaAge[i] = abs(StartingAges[i] - nt1)
		If (AndersenDeltaAge[i] > 0.1)
			reAndersen = 1
		EndIf
		
		// Compute a final set of ratios using Andersen's t1:
		xt1 = exp(l235*nt1) -1
		yt1 = exp(l238*nt1) -1
		zt1 = exp(l232*nt1) -1		
		
		// Compute fraction of common Pb (two different ways, probably best to use first as it doesn't depend on 208/232):
		FinalFracCommonPb[i] = (-yw[i]*xt1 + yw[i]*xt2 + yt2*xt1 + xw[i]*yt1 - xw[i]*yt2 - xt2*yt1)/(-yw[i]*xt1 + yw[i]*xt2 + yw[i]*c7*k*yt1 - yw[i]*c7*k*yt2)
		 //FinalFracCommonPb[i] = ((yt1-yt2)*(zt2-zw[i]) + (yw[i]-yt2)*(zt1-zt2))/(yw[i]*(zt1-zt2) + yw[i]*c8*uw[i]*(yt2-yt1))
		
		// Compute common Pb corrected ratios:
		FinalAnd207_235[i] = xw[i] - yw[i]*c7*k*FinalFracCommonPb[i]
		FinalAnd206_238[i] = yw[i]*(1-FinalFracCommonPb[i])
		FinalAnd208_232[i] = zw[i] - yw[i]*c8*uw[i]*FinalFracCommonPb[i]
		
		// Compute fraction of Pb lost:
		FinalFracLostPb[i] = (yt1 - FinalAnd206_238[i])/(yt1 - yt2)
	EndFor // End of main loop
	
	// Calculate common Pb corrected ages:
	FinalAgeAnd206_238 = (1/1e6)*(1/l238)*ln(FinalAnd206_238 + 1)
	FinalAgeAnd207_235 = (1/1e6)*(1/l235)*ln(FinalAnd207_235 + 1)
	FinalAgeAnd208_232 = (1/1e6)*(1/l232)*ln(FinalAnd208_232 + 1)
	
	Variable calcStopTime = DateTime
	KillWaves StartingAges, xw, yw, zw, uw
	Print "[VisualAge] ... Done. Calculation duration: " + num2str(calcStopTime-calcStartTime) + " s."
End

// !JAP
//###########################################################	









Function ResetFitWindows()
	string CurrentDFPath = getdatafolder(1)
	setDatafolder $ioliteDFpath("CurrentDRS","")
	string ListOfAutos = StringList("Auto_*",";")
	variable Index = 0
	variable NoOfAutoStrings = ItemsInList(ListOfAutos, ";")
	do
		SVar ThisAutoString = $ioliteDFpath("CurrentDRS",StringFromList(index, ListOfAutos, ";"))
		ThisAutoString = "Initialise"
		index+=1
	while(Index<NoOfAutoStrings)
	setDatafolder CurrentDFPath
End

//****Start Export data function (optional).  If present in a DRS file, this function is called by the export Stats routine when it is about to save the export stats text matrix to disk.
Function ExportFromActiveDRS(Output_DataTable,NameOfPathToDestinationFolder) //this line must be as written here
	wave/T Output_DataTable //will be a wave reference to the Output_DataTable text wave that is about to be saved
	String NameOfPathToDestinationFolder //will be the name of the path to the destination folder for this export.
	//have eliminated the UPb specific error propagation in favour of the generic error propagation function (which is now called at the end of the normal DRS function)
	string ErrorType	//use this string to store the relevant suffix, which will change depending on whether propagated errors are being exported
	//The below needs to take account of the new option of using either internal or propagated errors, they have different names!
	//need to add in appropriate error correlations and add a column with 238/206, this will make life easier later for people wanting to use Isoplot
	variable ColumnBeforeInsert = 1 + FindDimLabel(Output_DataTable, 1, "Final206_238_Prop2SE")	//get the column after 206/238
	ErrorType = "_Prop2SE"
	if(ColumnBeforeInsert == -1)	//if that label wasn't found then try the other error label option of no propagated error
		ColumnBeforeInsert = 1 + FindDimLabel(Output_DataTable, 1, "Final206_238_Int2SE")	//get the column after 206/238
		ErrorType = "_Int2SE"	//if it's internal only then need to change the name of the suffix used below
	endif
	string NameOfNewColumnLabel
	NameOfNewColumnLabel = "Final238_206" + ErrorType
	InsertPoints /M=1 ColumnBeforeInsert, 2, Output_DataTable	//insert two columns after the above column
	SetDimLabel 1, ColumnBeforeInsert, Final238_206, Output_DataTable	//and give them labels
	SetDimLabel 1, ColumnBeforeInsert+1, $NameOfNewColumnLabel, Output_DataTable	//and give them labels
	//Note that because num2str is limited to 5 decimal places it can't be used here, instead need a loop that uses sprintf
	string InvertedRatioAsString
	string InvertedErrorAsString
	string NameOfErrorLabel
	variable OriginalRatio
	variable OriginalError
	variable Counter = 0
	variable NoOfIntegs = dimSize(Output_DataTable, 0)
	do
		OriginalRatio = str2num(Output_DataTable[Counter][%$"Final206_238"])
		NameOfErrorLabel = "Final206_238"+ErrorType
		OriginalError = str2num(Output_DataTable[Counter][%$NameOfErrorLabel])
		sprintf InvertedRatioAsString,"%6.7g", (1 / OriginalRatio)
		sprintf InvertedErrorAsString,"%6.7g", (OriginalError / (OriginalRatio^2))	//to propagate the error, need to divide by the old ratio and multiply by the new. Because the new is 1/old, this is the same as dividing by the old twice
		if(grepstring(InvertedRatioAsString, "nan")==1)		//if this row is empty a NaN will be the result. want to replace this with an empty cell
			InvertedRatioAsString = ""
		endif
		if(grepstring(InvertedErrorAsString, "nan")==1)		//if this row is empty a NaN will be the result. want to replace this with an empty cell
			InvertedErrorAsString = ""
		endif
		NameOfErrorLabel = "Final238_206"+ErrorType
		Output_DataTable[Counter][%$"Final238_206"] = InvertedRatioAsString
		Output_DataTable[Counter][%$NameOfErrorLabel] = InvertedErrorAsString
		counter += 1
	while (Counter < NoOfIntegs-1)
	//unfortunately, for the error correlation code to work, also need to make an actual wave in the currentDRS folder
	duplicate/O $ioliteDFpath("CurrentDRS","Final206_238"), $ioliteDFpath("CurrentDRS", "Final238_206")
	wave Final238_206 = $ioliteDFpath("CurrentDRS", "Final238_206")
	Final238_206 = 1 / Final238_206
	//can now do error correlations for the two ratios used by Isoplot for normal and inverse U Pb plots
	NVar Calculate_207_235 = $ioliteDFpath("CurrentDRS","Calculate_207_235")
	NVar Calculate_207_206 = $ioliteDFpath("CurrentDRS","Calculate_207_206")
	if(Calculate_207_235 == 1)
		ErrorCorrelation(Output_DataTable, "Final207_235", "Final206_238","Final206_238"+ErrorType, "ErrorCorrelation_6_38vs7_35")
		ErrorCorrelation(Output_DataTable, "FinalAnd207_235", "FinalAnd206_238", "FinalAnd206_238"+ErrorType, "ErrorCorrelAnd_6_38vs7_35")
	endif
	if(Calculate_207_206 == 1)
		ErrorCorrelation(Output_DataTable, "Final238_206", "Final207_206","Final207_206"+ErrorType, "ErrorCorrelation_38_6vs7_6")
		ErrorCorrelation(Output_DataTable, "FinalPbC207_235", "FinalPbC206_238", "FinalPbC206_238"+ErrorType, "ErrorCorrelAnd_6_38vs7_35")		
	endif
end	//end of DRS intercept of data export - export routine will now save the (~altered) stats wave in the folder it supplied.

//the below 2 function are for the automatic setup of baselines and intermediates on the traces window.
Function AutoBaselines(buttonstructure) //Build the main display and integration window --- This is based off a button, so has button structure for the next few lines
	STRUCT WMButtonAction&buttonstructure
	if( buttonstructure.eventCode != 2 )
		return 0  // we only want to handle mouse up (i.e. a released click), so exit if this wasn't what caused it
	endif  //otherwise, respond to the popup click
	ClearAllTraces()
	AutoTrace(0, "U238", -300, 600, extraflag = "Primary")	//see the autotrace function for what these mean.	set both max and min to zero for autoscale.
	AutoTrace(1, "Th232", -300, 500)	//see the autotrace function for what these mean.
	AutoTrace(3, "Pb206", -300, 1500)	//see the autotrace function for what these mean.
	AutoTrace(4, "Pb207", -200, 2000)	//see the autotrace function for what these mean.
	AutoTrace(5, "Pb208", -50, 5000, extraflag = "Right")	//see the autotrace function for what these mean.
	AutoTrace(6, "Pb204", -800, 16000)	//see the autotrace function for what these mean.
end

Function AutoIntermediates(buttonstructure) //Build the main display and integration window --- This is based off a button, so has button structure for the next few lines
	STRUCT WMButtonAction&buttonstructure
	if( buttonstructure.eventCode != 2 )
		return 0  // we only want to handle mouse up (i.e. a released click), so exit if this wasn't what caused it
	endif  //otherwise, respond to the popup click
	ClearAllTraces()
	AutoTrace(0, "U238_CPS", 0, 0, extraflag = "Right")	//see the autotrace function for what these mean.	set both max and min to zero for autoscale.
	AutoTrace(1, "Raw_206_238", 0.07, .31, extraflag = "Primary")	//see the autotrace function for what these mean.
	AutoTrace(2, "Raw_207_235", 0.2, 6.7)	//see the autotrace function for what these mean.
	AutoTrace(3, "Raw_208_232", 0.02, 0.39)	//see the autotrace function for what these mean.
	AutoTrace(4, "Pb206_CPS", 0, 0)	//see the autotrace function for what these mean.	set both max and min to zero for autoscale.
	AutoTrace(5, "Pb207_CPS", 0, 0)	//see the autotrace function for what these mean.	set both max and min to zero for autoscale.
	AutoTrace(6, "Pb208_CPS", 0, 0)	//see the autotrace function for what these mean.	set both max and min to zero for autoscale.
	AutoTrace(7, "Raw_207_206", 0.02, 0.16, extraflag = "Hidden")	//see the autotrace function for what these mean.
	AutoTrace(8, "Raw_206_208", 5, 17, extraflag = "Hidden")	//see the autotrace function for what these mean.
end

