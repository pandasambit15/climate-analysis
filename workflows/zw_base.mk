# zw_base.mk
#
# Description: Basic workflow that underpins all other zonal wave (zw) workflows 
#
# To execute:
#   make -n -B -f zw_base.mk  (-n is a dry run) (-B is a force make)

# Pre-processing:
#   The regirdding (if required) needs to be done beforehand 
#   (probably using cdo remapcon2,r360x181 in.nc out.nc)
#   So does the zonal anomaly


# Define marcos
include zw_config.mk

all : ${TARGET}


# Temporal averaging of core data

## Meridional wind

V_ORIG=${DATA_DIR}/va_${DATASET}_${LEVEL}_daily_native.nc
V_RUNMEAN=${DATA_DIR}/va_${DATASET}_${LEVEL}_${TSCALE_LABEL}_native.nc
${V_RUNMEAN} : ${V_ORIG}
	cdo ${TSCALE} $< $@

## Wave envelope

ENV_RUNMEAN=${ZW_DIR}/envva_${ENV_WAVE_LABEL}_${DATASET}_${LEVEL}_${TSCALE_LABEL}_native.nc
${ENV_RUNMEAN} : ${V_RUNMEAN}
	bash ${DATA_SCRIPT_DIR}/calc_fourier_transform.sh $< va $@ ${WAVE_MIN} ${WAVE_MAX} hilbert ${PYTHON} ${DATA_SCRIPT_DIR} ${TEMPDATA_DIR}

## Zonal wind

U_ORIG=${DATA_DIR}/ua_${DATASET}_${LEVEL}_daily_native.nc
U_RUNMEAN=${DATA_DIR}/ua_${DATASET}_${LEVEL}_${TSCALE_LABEL}_native.nc
${U_RUNMEAN} : ${U_ORIG}
	cdo ${TSCALE} $< $@

## Streamfunction

SF_ORIG=${DATA_DIR}/sf_${DATASET}_${LEVEL}_daily_native.nc
${SF_ORIG} : ${U_ORIG} ${V_ORIG}
	bash ${DATA_SCRIPT_DIR}/calc_wind_quantities.sh streamfunction $< ua $(word 2,$^) va $@ ${PYTHON} ${DATA_SCRIPT_DIR} ${TEMPDATA_DIR}

SF_ANOM_RUNMEAN=${DATA_DIR}/sf_${DATASET}_${LEVEL}_${TSCALE_LABEL}-anom-wrt-all_native.nc
${SF_ANOM_RUNMEAN} : ${SF_ORIG} 
	cdo ${TSCALE} -ydaysub $< -ydayavg $< $@

SF_ZONAL_ANOM=${DATA_DIR}/sf_${DATASET}_${LEVEL}_daily_native-zonal-anom.nc
${SF_ZONAL_ANOM} : ${SF_ORIG}       
	bash ${DATA_SCRIPT_DIR}/calc_zonal_anomaly.sh $< sf $@ ${PYTHON} ${DATA_SCRIPT_DIR} ${TEMPDATA_DIR}

SF_ZONAL_ANOM_RUNMEAN=${DATA_DIR}/sf_${DATASET}_${LEVEL}_${TSCALE_LABEL}_native-zonal-anom.nc 
${SF_ZONAL_ANOM_RUNMEAN} : ${SF_ZONAL_ANOM}
	cdo ${TSCALE} $< $@

## Geopotential height

ZG_ORIG=${DATA_DIR}/zg_${DATASET}_${LEVEL}_daily_native.nc

ZG_ZONAL_ANOM=${DATA_DIR}/zg_${DATASET}_${LEVEL}_daily_native-zonal-anom.nc
${ZG_ZONAL_ANOM} : ${ZG_ORIG}       
	bash ${DATA_SCRIPT_DIR}/calc_zonal_anomaly.sh $< zg $@ ${PYTHON} ${DATA_SCRIPT_DIR} ${TEMPDATA_DIR}

ZG_ZONAL_ANOM_RUNMEAN=${DATA_DIR}/zg_${DATASET}_${LEVEL}_${TSCALE_LABEL}_native-zonal-anom.nc 
${ZG_ZONAL_ANOM_RUNMEAN} : ${ZG_ZONAL_ANOM}
	cdo ${TSCALE} $< $@


## Sea surface temperature

TOS_ORIG=${DATA_DIR}/tos_${DATASET}_surface_daily_native-tropicalpacific.nc
TOS_RUNMEAN=${DATA_DIR}/tos_${DATASET}_surface_${TSCALE_LABEL}_native-tropicalpacific.nc
${TOS_RUNMEAN} : ${TOS_ORIG}
	cdo ${TSCALE} $< $@

# Mean sea level pressure

PSL_ORIG=${DATA_DIR}/psl_${DATASET}_surface_daily_native-shextropics30.nc
PSL_RUNMEAN=${DATA_DIR}/psl_${DATASET}_surface_${TSCALE_LABEL}_native-shextropics30.nc
${PSL_RUNMEAN} : ${PSL_ORIG}
	cdo ${TSCALE} $< $@


# Common indices

## Phase and amplitude of each Fourier component

FOURIER_INFO=${ZW_DIR}/fourier_zw_${COE_WAVE_LABEL}-va_${DATASET}_${LEVEL}_${TSCALE_LABEL}_native.nc 
${FOURIER_INFO} : ${V_RUNMEAN}
	bash ${DATA_SCRIPT_DIR}/calc_fourier_transform.sh $< va $@ ${WAVE_MIN} ${WAVE_MAX} coefficients ${PYTHON} ${DATA_SCRIPT_DIR} ${TEMPDATA_DIR}

## Planetary Wave Index

PWI_INDEX=${INDEX_DIR}/pwi_va_${DATASET}_${LEVEL}_${TSCALE_LABEL}_native.nc 
${PWI_INDEX} : ${ENV_RUNMEAN}
	${PYTHON} ${DATA_SCRIPT_DIR}/calc_climate_index.py PWI $< envva $@

DATES_PWI_HIGH=${INDEX_DIR}/dates_pwigt${INDEX_HIGH_THRESH}_${DATASET}_${LEVEL}_${TSCALE_LABEL}_native.txt
${DATES_PWI_HIGH} : ${PWI_INDEX}
	${PYTHON} ${DATA_SCRIPT_DIR}/create_date_list.py $< pwi $@ --metric_threshold ${INDEX_HIGH_THRESH} --threshold_direction greater

DATES_PWI_LOW=${INDEX_DIR}/dates_pwilt${INDEX_LOW_THRESH}_${DATASET}_${LEVEL}_${TSCALE_LABEL}_native.txt
${DATES_PWI_LOW} : ${PWI_INDEX}
	${PYTHON} ${DATA_SCRIPT_DIR}/create_date_list.py $< pwi $@ --metric_threshold ${INDEX_LOW_THRESH} --threshold_direction less

## ZW3 index 

ZW3_INDEX=${INDEX_DIR}/zw3index_${DATASET}_500hPa_${TSCALE_LABEL}_native-zonal-anom.nc 
${ZW3_INDEX} : ${ZG_ZONAL_ANOM_RUNMEAN}
	${PYTHON} ${DATA_SCRIPT_DIR}/calc_climate_index.py ZW3 $< zg $@

## Nino 3.4

NINO34_INDEX=${INDEX_DIR}/nino34_${DATASET}_surface_${TSCALE_LABEL}_native.nc 
${NINO34_INDEX} : ${TOS_RUNMEAN}
	${PYTHON} ${DATA_SCRIPT_DIR}/calc_climate_index.py NINO34 $< tos $@

DATES_ELNINO=${INDEX_DIR}/dates_nino34elnino_${DATASET}_surface_${TSCALE_LABEL}_native.txt
${DATES_ELNINO} : ${NINO34_INDEX}
	${PYTHON} ${DATA_SCRIPT_DIR}/create_date_list.py $< nino34 $@ --metric_threshold 0.5 --threshold_direction greater

DATES_LANINA=${INDEX_DIR}/dates_nino34lanina_${DATASET}_surface_${TSCALE_LABEL}_native.txt
${DATES_LANINA} : ${NINO34_INDEX}
	${PYTHON} ${DATA_SCRIPT_DIR}/create_date_list.py $< nino34 $@ --metric_threshold -0.5 --threshold_direction less

## Southern Annular Mode

SAM_INDEX=${INDEX_DIR}/sam_${DATASET}_surface_${TSCALE_LABEL}_native.nc 
${SAM_INDEX} : ${PSL_RUNMEAN}
	${PYTHON} ${DATA_SCRIPT_DIR}/calc_climate_index.py SAM $< psl $@

DATES_SAM_POS=${INDEX_DIR}/dates_samgt75pct_${DATASET}_surface_${TSCALE_LABEL}_native.txt
${DATES_SAM_POS} : ${SAM_INDEX}
	${PYTHON} ${DATA_SCRIPT_DIR}/create_date_list.py $< sam $@ --metric_threshold 75pct --threshold_direction greater

DATES_SAM_NEG=${INDEX_DIR}/dates_samlt25pct_${DATASET}_surface_${TSCALE_LABEL}_native.txt
${DATES_SAM_NEG} : ${SAM_INDEX}
	${PYTHON} ${DATA_SCRIPT_DIR}/create_date_list.py $< sam $@ --metric_threshold 25pct --threshold_direction less

## Amundsen Sea Low

ASL_INDEX=${INDEX_DIR}/asl_${DATASET}_surface_${TSCALE_LABEL}_native.nc 
${ASL_INDEX} : ${PSL_RUNMEAN}
	${PYTHON} ${DATA_SCRIPT_DIR}/calc_climate_index.py ASL $< psl $@

