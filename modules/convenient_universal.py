"""Collection of convenient functions that will work with my anaconda or uvcdat install

Included functions:
adjust_lon_range     -- Express longitude values in desired 360 degree interval
get_threshold        -- Turn the user input threshold into a numeric threshold
single2list          -- Check if item is a list, then convert if not

"""

import numpy
from scipy import stats


def adjust_lon_range(lons, radians=True, start=0.0):
    """Express longitude values in the 360 degree (or 2*pi radians)
    interval that begins at start.

    Arguments:
       lons      List of longitude axis values (monotonically increasing)
       radians   Specify whether the input data are in radians (True) or
                 degrees (False). Output will be the same units.
       start     Start value for the output axis (add 360 degrees or 2*pi
                 radians to get the end point)
    """
    
    lons = single2list(lons, numpy_array=True)    
    
    interval360 = 2.0*numpy.pi if radians else 360.0
    end = start + interval360    
    
    less_than_start = numpy.ones([len(lons),])
    while numpy.sum(less_than_start) != 0:
        lons = numpy.where(lons < start, lons + interval360, lons)
        less_than_start = lons < start
    
    more_than_end = numpy.ones([len(lons),])
    while numpy.sum(more_than_end) != 0:
        lons = numpy.where(lons >= end, lons - interval360, lons)
        more_than_end = lons >= end

    return lons


def get_significance(data_included, data_excluded, size_included, size_excluded):
    """Perform significance test.
    
    The approach for the significance test is to compare the mean of the included
    data sample with that of the excluded data sample via an independent, two-sample,
    parametric t-test (for details, see Wilks textbook). 
    
    http://stackoverflow.com/questions/21494141/how-do-i-do-a-f-test-in-python

    FIXME: If equal_var=False then it will perform a Welch's t-test, which is for samples
    with unequal variance (early versions of scipy don't have this option). To test whether
    the variances are equal or not you use an F-test (i.e. do the test at each grid point and
    then assign equal_var accordingly). If your data is close to normally distributed you can 
    use the Barlett test (scipy.stats.bartlett), otherwise the Levene test (scipy.stats.levene).
    
    FIXME: I need to account for autocorrelation in the data by calculating an effective
    sample size (see Wilkes, p 147). I can get the autocorrelation using either
    genutil.autocorrelation or the acf function in the statsmodels time series analysis
    python library, however I can't see how to alter the sample size in stats.ttest_ind.

    FIXME: I also need to consider whether a parametric t-test is appropriate. One of my samples
    might be very non-normally distributed, which means a non-parametric test might be better. 
    
    """

#    alpha = 0.05 
#    w, p_value = scipy.stats.levene(data_included, data_excluded)
#    if p_value > alpha:
#        equal_var = False# Reject the null hypothesis that Var(X) == Var(Y)
#    else:
#        equal_var = True

    t, pvals = stats.ttest_ind(data_included, data_excluded, axis=0, equal_var=True) # stats.mstats.ttest_ind would be better but does not have equal_var option
    print 'WARNING: Significance test did not account for autocorrelation (and is thus overconfident), assumed equal variances and did not handle masks'

    pval_atts = {'id': 'p',
                 'standard_name': 'p_value',
                 'long_name': 'Two-tailed p-value',
                 'units': ' ',
                 'history': """Standard independent two sample t-test comparing the data sample that meets the composite criteria (size=%s) to a sample containing the remaining data (size=%s)""" %(str(size_included), str(size_excluded)),
                 'reference': 'scipy.stats.ttest_ind(a, b, axis=t, equal_var=False)'}

    return pvals, pval_atts


def get_threshold(data, threshold_str, axis=None):
    """Turn the user input threshold into a numeric threshold"""
    
    if 'pct' in threshold_str:
        value = float(re.sub('pct', '', threshold_str))
        threshold_float = numpy.percentile(data, value, axis=axis)
    else:
        threshold_float = float(threshold_str)
    
    return threshold_float


def single2list(item, numpy_array=False):
    """Check if item is a list, then convert if not"""
    
    try:
        test = len(item)
    except TypeError:
        output = [item,]
    else:
        output = item 
        
    if numpy_array and not isinstance(output, numpy.ndarray):
        return numpy.array(output)
    else:
        return output
