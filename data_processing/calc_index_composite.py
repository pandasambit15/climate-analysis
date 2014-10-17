"""
Filename:     calc_index_composite.py
Author:       Damien Irving, d.irving@student.unimelb.edu.au
Description:  For a given variable, calculate a composite of a related index

"""

# Import general Python modules #

import sys, os, pdb
import argparse
import numpy


# Import my modules #

cwd = os.getcwd()
repo_dir = '/'
for directory in cwd.split('/')[1:]:
    repo_dir = os.path.join(repo_dir, directory)
    if directory == 'phd':
        break

modules_dir = os.path.join(repo_dir, 'modules')
sys.path.append(modules_dir)

try:
    import netcdf_io as nio
    import convenient_universal as uconv
except ImportError:
    raise ImportError('Must run this script from anywhere within the phd git repo')


# Define functions #

def main(inargs):
    """Run the program."""
    
    # Initialise output #

    outdata_list = []
    outvar_atts_list = []
    outvar_axes_list = []

    if inargs.time:
        start_date, end_date = inargs.time
    else:
        start_date = end_date = 'none'

    for season in inargs.seasons:

	# Prepate input data #
        
        selector = 'none' if season == 'annual' else season
	var_indata = nio.InputData(inargs.varfile, inargs.var, time=(start_date, end_date, selector),  **nio.dict_filter(vars(inargs), ['region']))
        metric_indata = nio.InputData(inargs.metricfile, inargs.metric, time=(start_date, end_date, selector))

        # Find threshold for variable and get boolean index array for samples > and <= the threshold #

        time_index = var_indata.data.getOrder().index('t')
        assert time_index == 0, "If time is not the first axis, the numpy.resize broadcasting in this script will mess up the data"
        threshold = uconv.get_threshold(var_indata.data, inargs.threshold, axis=time_index)
        threshold = numpy.resize(threshold, var_indata.data.shape)

        included_indexes = var_indata.data > threshold
        excluded_indexes = numpy.invert(included_indexes)

        # Create masked metric arrays #

        metric_data = numpy.resize(metric_indata.data, var_indata.data.shape)
        metric_data_included = numpy.ma.masked_array(metric_data, mask=included_indexes)
        metric_data_excluded = numpy.ma.masked_array(metric_data, mask=excluded_indexes)
            
	# Calculate composite # 

	#composite, composite_atts = get_composite(data_included, inargs.var, 
        #                                	  indata.data.long_name, indata.data.standard_name, indata.data.units,
        #                                	  season)
	
        composite_mean = metric_data_included.mean(axis=0)

        composite_atts = {'id': inargs.metric,
                          'standard_name': metric_indata.data.standard_name,
                          'long_name': metric_indata.data.long_name,
                          'units': metric_indata.data.units,
                          'history': 'Composite mean for %s season' %(season)}

        outdata_list.append(composite)
	outvar_atts_list.append(composite_atts)
	outvar_axes_list.append(composite.getAxisList())

	# Perform significance test # 

        pval, pval_atts = uconv.get_significance(metric_data_included, metric_data_excluded)
        outdata_list.append(pval)
        outvar_atts_list.append(pval_atts)
        outvar_axes_list.append(composite.getAxisList())	


    # Write the output file #

    var_indata.global_atts['history'] = '%s \n%s' %(var_indata.global_atts['history'], metric_indata.global_atts['history'])

    nio.write_netcdf(inargs.outfile, " ".join(sys.argv), 
                     var_indata.global_atts, 
                     outdata_list,
                     outvar_atts_list, 
                     outvar_axes_list)


if __name__ == '__main__':

    extra_info =""" 
example (vortex.earthsci.unimelb.edu.au):

author:
  Damien Irving, d.irving@student.unimelb.edu.au

"""

    description='Calculate composite'
    parser = argparse.ArgumentParser(description=description,
                                     epilog=extra_info, 
                                     argument_default=argparse.SUPPRESS,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument("varfile", type=str, help="Name of input file containing variable of interest")
    parser.add_argument("var", type=str, help="Name of variable in varfile")
    parser.add_argument("metricfile", type=str, help="Name of file containing metric")
    parser.add_argument("metric", type=str, help="Name of metric in metricfile")
    parser.add_argument("threshold", type=str,help="Threshold for defining an extreme event. Can be percentile (e.g. 90pct) or raw value.")
    parser.add_argument("outfile", type=str, help="Output file name")
    
    parser.add_argument("--time", type=str, nargs=2, metavar=('START_DATE', 'END_DATE'), default=None,
                        help="Time period over which to calculate the composite [default = entire]")
    parser.add_argument("--seasons", type=str, nargs='*', default=('DJF', 'MAM', 'JJA', 'SON', 'annual'),
                        help="Seasons for which to output a composite [default = DJF, MAM, JJA, SON, annual]")
    parser.add_argument("--region", type=str, choices=nio.regions.keys(),
                        help="Region over which to calculate the composite [default: entire]")

    args = parser.parse_args()            


    print 'Input file: ', args.infile
    print 'Output file: ', args.outfile  

    main(args)