# Running_Wild
Data manipulation and analysis for "Running Wild" virtual race, fundraiser for Piedmont Wildlife Center
https://run.piedmontwildlifecenter.org/

# The Problem
As it is a virtual race, competitors submit individual race routes that are tracked using smartphone apps such as Strava. However, we needed a way to compare the different race routes which inevitably had differences in steepness (gradient). The code shows calculation of a Grade Adjusted Pace (GAP) - that is the speed adjusted to account for the different gradients in each individual race, in order to make the race as fair as possible given the differences in routes. 
More information on GAP here: https://medium.com/strava-engineering/an-improved-gap-model-8b07ae8886c3   

# Files
Files include 3 scripts and one sample gpx file
- "RunScript.Sept2020.R": script for use within the webpage, uses the trackeR package to process gpx/ tmx files
  - input is a user-submitted gpx or tcx file and a specified run distance (5K, 10K, or 15K) 
  - outputs a normalized pace (m/s), the actual pace (m/s), and the absolute elevational change in meters

- "RunScriptWithViz.draft2.R": includes the above, and also includes a visualization of the polynomial formula used to relate gradient to adjusted pace and additional race graphs (eg distance versus altitude) created using ggplot2

- "5kRun.draft1.py": similar to above but in python, uses the geopy package to calculate geodesic distance from lat/long coordinates and also includes additional race graphs (eg map of the race route created from lat/long coordinates) created using matplotlib
