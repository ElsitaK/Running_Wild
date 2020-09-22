#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Aug  7 12:56:25 2020

@author: Elsita Kiekebusch
"""

#Normalized Graded Speed
#"Uses polynomial formula developed by Strava to standardize race times 
#across different individually submitted routes"

#based on Strava research described by Drew Robb here:
#https://medium.com/strava-engineering/an-improved-gap-model-8b07ae8886c3   

#and R code by Quantixed where he first extracted the formula
#and then applied it to gpx files
#https://quantixed.org/2020/05/19/running-free-calculating-efficiency-factor-in-r/

#useful python code:
#https://pypi.org/project/gpxpy/#:~:text=gpxpy%20%2D%2D%20GPX%20file%20parser,GPS%20track%20editor%20and%20organizer.
#https://towardsdatascience.com/how-tracking-apps-analyse-your-gps-data-a-hands-on-tutorial-in-python-756d4db6715d    


####packages needed
import os
import gpxpy
import pandas as pd
import matplotlib.pyplot as plt
from geopy import distance #for the vincenty distance calculation



####file loading
#this will need to be updated in order to work on multiple files
#right now specifies a specific path to 1 file

#get filepath 
#ultimately, will depend on how we load in the racer's files
path = os.getcwd() #get current working directory
gpxFilename = "29_not athletic 2.gpx"
filepath = str(os.getcwd()) + '/' + gpxFilename
#print(filepath)


#load file
gpx_file = open(gpxFilename, 'r')
gpx = gpxpy.parse(gpx_file)



####data processing

#get the data points
data = gpx.tracks[0].segments[0].points


#get data into a dataframe
#initialize empty dataframe
df = pd.DataFrame(columns=['longitude', 'latitude', 'altitude', 'time'])
#iterate over data points, placing them into the df
for point in data:
    df = df.append({'longitude': point.longitude, 'latitude' : point.latitude, 'altitude' : point.elevation, 'time' : point.time}, ignore_index=True)

#formatting of time is odd, let's look
df['time'].dtypes
type(df['time'][0])

#removes the timezone assignment (eg the +00:00) - now the matplotlib works
df['time'] = df['time'].dt.tz_localize(None)

#now need to add distances between points
#essentially modified pythagoras calculations on the lat/long values
#but, these need to take into account that the earth is a sphere not flat
#at this point not taking into account the elevational distances (eg adjusted distance) or "3D distance")

#looping through all values in the dataframe
#calculating the Geodesic distance - is this 2d?? because I dont want it to take into account the elevation i think
#also calculating altitudinal, time and distance differences between each points

#initialize empty lists
alt_dif = [0]
time_dif = [0]
dist_geo_no_alt = [0] #cum dist
dist_dif_geo_2d = [0] #dist between points

#not sure why it is on the data and not the df
for index in range(len(data)):
    if index == 0:
        pass
    else:
        start = data[index-1]
        stop = data[index]
        #calculates distance between index-1 point and index point
        distance_geo_2d = distance.geodesic((start.latitude, start.longitude), (stop.latitude, stop.longitude)).m
        #appends the value to the list during each iteration
        dist_dif_geo_2d.append(distance_geo_2d) 
        #cumulative distance
        dist_geo_no_alt.append(dist_geo_no_alt[-1] + distance_geo_2d)
        
        #calculate difference in elevation for each between points
        alt_d = stop.elevation - start.elevation #should be stop - start
        alt_dif.append(alt_d)

        #calculate difference in time (in seconds?) for each between points
        time_delta = (stop.time - start.time).total_seconds()
        time_dif.append(time_delta)
        
        
#add the lists to df
df['distance'] = dist_geo_no_alt 
df['dist_point'] = dist_dif_geo_2d   
df['alti_point'] = alt_dif
df['time_point'] = time_dif #in seconds
     
#now we need speed and gradient diff to get the ngs
#get gradient - if this works, idk why we used data above in the first place
grad_dif = []

for index in range(len(df)):    
    try:    
        grad_d = df['alti_point'][index] / df['dist_point'][index] * 100
        grad_dif.append(grad_d)
        #or no need to make empty list (?)
        #df['grad_point'][index] = df['alti_point'][index] / df['dist_point'][index]
    except: #dividing by zero
        grad_dif.append(0)   

df['grad_point'] = grad_dif



#get speed = distance / time
speed_dif = []

for index in range(len(df)):    
    try:    
        speed_d = df['dist_point'][index] / df['time_point'][index]
        speed_dif.append(speed_d)
    except: #dividing by zero
        speed_dif.append(0)   

df['speed'] = speed_dif



#change nan to zero for speed and grad point
df = df.fillna(0) #did not modify in place, had to save it


#get normalized graded speed using polynomial formula
ngs_dif = []

for index in range(len(df)):    
    try:    
        ngs_d = df['speed'][index] * (0.98462 + (0.030266 * df['grad_point'][index]) + 
                  (0.0018814 * df['grad_point'][index] ** 2) + 
                  (-3.3882e-06 * df['grad_point'][index] ** 3) + 
                  (-4.5704e-07 * df['grad_point'][index] ** 4))
        ngs_dif.append(ngs_d)
    except: #dividing by zero
        ngs_dif.append(0)   

df['ngs'] = ngs_dif

#TASK TO DO: within pre-processing step need to cut off after exactly 5km or 10km etc
#so it will only use those points



####Visualizations 
#all of these are options for presentation
#TASK TO DO: was too lazy to do this thus far - change the time to time elapsed

#map of route - could be overlaid with an actual real map
#NOTE FOR SOME REASON IT DOESNT LIKE THE SCALE OF THE LAT/LONG POINTS
#wont automatically run for some reason
fig, ax = plt.subplots()
ax.plot(df['longitude'], df['latitude'])
ax.set(xlabel = 'Longitude' , ylabel = 'Latitude')
plt.show()

#change in route elevation over time
#x axis is the actual time of day, could be minutes/ seconds elapsed
fig, ax = plt.subplots()
ax.plot(df['time'], df['altitude']) 
ax.set(xlabel = 'Time' , ylabel = 'Altitude (m above sea level)')
plt.show()


#change in gradient over time
fig, ax = plt.subplots()
plt.plot(df['time'], df['grad_point']) 
ax.set(xlabel = 'Time' , ylabel = 'Gradient (slope)')
plt.show()

#change in speed over time
fig, ax = plt.subplots()
plt.plot(df['time'], df['speed']) 
ax.set(xlabel = 'Time' , ylabel = 'Speed (m/s)')
plt.show()



####Speed and Normalized Speed Calculations
#calculate pace overall
#remember speed = distance / time

#here dividing total distance in meters (final distance point in column)
# by time in seconds (sum of all single time points)
speed_overall = df['distance'][len(df)-1] / df['time_point'].sum()
print(speed_overall)

#time it actually  took in minutes
actual_time = df['time_point'].sum() / 60
print(actual_time) 

#calculate adjusted distance column (normalized speed * time in seconds)
#this will account for differences in time of each time point
dist_adj_dif = []
for i in range(len(df)):
   dist_adj_d = df['ngs'][i] * df['time_point'][i]
   dist_adj_dif.append(dist_adj_d)

df['dist_adj'] = dist_adj_dif
   
#then get dist_adj / time (i think) (as above)
#we either want this (below) or we want the new time -- or both :)
ngs_overall = df['dist_adj'].sum() / df['time_point'].sum()
print(ngs_overall)

#this could be what we ultimately want below:
#new adjusted time given normalized speed (ngs) in minutes
normalized_time = (df['distance'][len(df)-1] / ngs_overall) /60
print(normalized_time) 

#meaning:
#the difference between normalized_time and actual_time
#is how much faster or slower they would have gone had it been a flat race    



#TASK TO DO: add a converter to mph? (currently in m/s)



