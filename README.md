# mangldat
Program to convert Rockwell Software's FactoryTalk View SE's data log .dat files to a single .csv file.

The program runs from the command line taking the tagname.dat and float.dat filenames as parameters. The
tag names are then used for column headers in the first row, with data for each time stamp following in the
subsequent rows. Output is written to standard output and can be piped or redirected from the command line 
as needed.
