#!/bin/bash 

Subjlist="23_noT2_test3" #Space delimited list of subject IDs
StudyFolder="/home/fs0/jmouthuy/scratch/subject_23" #Location of Subject folders (named by subjectID)
EnvironmentScript="/home/fs0/jmouthuy/scratch/subject_23/23_noT2_test/SetUpHCPPipelineJBM.sh" #Pipeline environment script

# Requirements for this script
#  installed versions of: FSL5.0.2 or higher , FreeSurfer (version 5.2 or higher) , gradunwarp (python code from MGH)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

#Set up pipeline environment variables and software
. ${EnvironmentScript}

# Log the originating call
echo "$@"

if [ X$SGE_ROOT != X ] ; then
    QUEUE="-q long.q"
fi

PRINTCOM=""
#PRINTCOM="echo"
#QUEUE="-q veryshort.q"


########################################## INPUTS ########################################## 

#
#Naming conventions

# ONLY ONE T1 IMAGE AND GRADIENT FIELD MAP
#	${StudyFolder}/${Subject}/T1.nii.gz
#	
#	${StudyFolder}/${Subject}/b_mag_brain.nii.gz
#	${StudyFolder}/${Subject}/b_ph.nii.gz

#Change Scan Settings: FieldMap Delta TE, Sample Spacings, and $UnwarpDir to match your images
#These are set to match the HCP Protocol by default

#If using gradient distortion correction, use the coefficents from your scanner
#The HCP gradient distortion coefficents are only available through Siemens
#Gradient distortion in standard scanners like the Trio is much less than for the HCP Skyra.


######################################### DO WORK ##########################################


for Subject in $Subjlist ; do
  echo $Subject
  
  #Input Images
  #Define inputs as they are in the study
  T1wInputImages=${StudyFolder}/${Subject}/T1.nii.gz
  T2wInputImages=""
  MagnitudeInputName="${StudyFolder}/${Subject}/mag_raw_concat_23.nii.gz" #Expects 4D magitude volume with two 3D timepoints or "NONE" if not used
  PhaseInputName="${StudyFolder}/${Subject}/ph_MB_23.nii.gz" #Expects 3D phase difference volume or "NONE" if not used


  SpinEchoPhaseEncodeNegative="NONE" #For the spin echo field map volume with a negative phase encoding direction (LR in HCP data), set to NONE if using regular FIELDMAP
  SpinEchoPhaseEncodePositive="NONE" #For the spin echo field map volume with a positive phase encoding direction (RL in HCP data), set to NONE if using regular FIELDMAP

  #Templates
  T1wTemplate="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm.nii.gz" #MNI0.7mm template
  T1wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain.nii.gz" #Brain extracted MNI0.7mm template
  T1wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz" #MNI2mm template
  TemplateMask="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain_mask.nii.gz" #Brain mask MNI0.7mm template
  Template2mmMask="${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz" #MNI2mm template

  #Scan Settings
  TE="2.46" #delta TE in ms for field map or "NONE" if not used
  DwellTime="NONE" #Echo Spacing or Dwelltime of Spin Echo Field Map or "NONE" if not used
  SEUnwarpDir="NONE" #x or y (minus or not does not matter) "NONE" if not used 
  T1wSampleSpacing="0.0000074" #DICOM field (0019,1018) in s or "NONE" if not used
  UnwarpDir="y" #z appears to be best or "NONE" if not used
  GradientDistortionCoeffs="/home/fs0/rosas/scratch/analysis/coeff_verio.grad.grad" #Location of Coeffs file or "NONE" to skip
  
  # RS: Configure Templates and Scan settings for T2 (if it exists) 
  if [ ! $T2wInputImages = "" ] ; then
   T2wTemplate="${HCPPIPEDIR_Templates}/MNI152_T2_0.7mm.nii.gz" #MNI0.7mm T2wTemplate
   T2wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T2_0.7mm_brain.nii.gz" #Brain extracted MNI0.7mm T2wTemplate
   T2wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T2_2mm.nii.gz" #MNI2mm T2wTemplate
   T2wSampleSpacing="0.0000021" #DICOM field (0019,1018) in s or "NONE" if not used
  else
   T2wInputImages="NONE"
   T2wTemplate="NONE" 
   T2wTemplateBrain="NONE" 
   T2wTemplate2mm="NONE" 
   T2wSampleSpacing="NONE" 
  fi
  

#Config Settings
  BrainSize="150" #BrainSize in mm, 150 for humans
  FNIRTConfig="${HCPPIPEDIR_Config}/T1_2_MNI152_2mm.cnf" #FNIRT 2mm T1w Config
  AvgrdcSTRING="FIELDMAP" #Averaging and readout distortion correction methods: "NONE" = average any repeats with no readout correction "FIELDMAP" = average any repeats and use field map for readout correction "TOPUP" = average and distortion correct at the same time with topup/applytopup only works for 2 images currently
  TopupConfig="NONE" #Config for topup or "NONE" if not used

  ${FSLDIR}/bin/fsl_sub ${QUEUE} \
     ${HCPPIPEDIR}/PreFreeSurfer/PreFreeSurferPipeline.sh \
      --path="$StudyFolder" \
      --subject="$Subject" \
      --t1="$T1wInputImages" \
      --t2="$T2wInputImages" \
      --t1template="$T1wTemplate" \
      --t1templatebrain="$T1wTemplateBrain" \
      --t1template2mm="$T1wTemplate2mm" \
      --t2template="$T2wTemplate" \
      --t2templatebrain="$T2wTemplateBrain" \
      --t2template2mm="$T2wTemplate2mm" \
      --templatemask="$TemplateMask" \
      --template2mmmask="$Template2mmMask" \
      --brainsize="$BrainSize" \
      --fnirtconfig="$FNIRTConfig" \
      --fmapmag="$MagnitudeInputName" \
      --fmapphase="$PhaseInputName" \
      --echodiff="$TE" \
      --SEPhaseNeg="$SpinEchoPhaseEncodeNegative" \
      --SEPhasePos="$SpinEchoPhaseEncodePositive" \
      --echospacing="$DwellTime" \
      --seunwarpdir="$SEUnwarpDir" \
      --t1samplespacing="$T1wSampleSpacing" \
      --t2samplespacing="$T2wSampleSpacing" \
      --unwarpdir="$UnwarpDir" \
      --gdcoeffs="$GradientDistortionCoeffs" \
      --avgrdcmethod="$AvgrdcSTRING" \
      --topupconfig="$TopupConfig" \
      --printcom=${PRINTCOM}

      
  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

  echo "set -- --path=${StudyFolder} \
      --subject=${Subject} \
      --t1=${T1wInputImages} \
      --t2=${T2wInputImages} \ 
      --t1template=${T1wTemplate} \
      --t1templatebrain=${T1wTemplateBrain} \
      --t1template2mm=${T1wTemplate2mm} \
      --t2template=${T2wTemplate} \
      --t2templatebrain=${T2wTemplateBrain} \
      --t2template2mm=${T2wTemplate2mm} \
      --templatemask=${TemplateMask} \
      --template2mmmask=${Template2mmMask} \
      --brainsize=${BrainSize} \
      --fnirtconfig=${FNIRTConfig} \
      --fmapmag=${MagnitudeInputName} \
      --fmapphase=${PhaseInputName} \
      --echodiff=${TE} \
      --SEPhaseNeg=${SpinEchoPhaseEncodeNegative} \
      --SEPhasePos=${SpinEchoPhaseEncodePositive} \
      --echospacing=${DwellTime} \
      --seunwarpdir=${SEUnwarpDir} \     
      --t1samplespacing=${T1wSampleSpacing} \
      --t2samplespacing=${T2wSampleSpacing} \
      --unwarpdir=${UnwarpDir} \
      --gdcoeffs=${GradientDistortionCoeffs} \
      --avgrdcmethod=${AvgrdcSTRING} \
      --topupconfig=${TopupConfig} \
      --printcom=${PRINTCOM}"

  echo ". ${EnvironmentScript}"

done
