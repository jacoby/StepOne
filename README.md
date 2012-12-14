StepOne
=======

Perl Tool for creating .EDS files for ABI StepOne qPCR systems

Usage
=====

There is one user-accessable function in StepOne, which is make_eds.
It takes a hashref which contains the following:

* experiment_name, the name for the whole of the plate
* sample_names, an arrayref holding the name of each sample
* replicates, which is the number of wells per sample
* std_curve, which is a number showing the number of points on the standard curve
    
Usage is described in package.pl

.EDS files are ZIP files. Unzip one into ~/.stepone/Source, and this will
be the origin of most of the files created. This module only creates two,
plate_setup.xml and experiment.xml. Copy the .tt files into ~/.stepone/Templates
and Template Toolkit will be called on them.

