
library(trackeR)
library(zoo)
library(hms)
library(lubridate)

setwd('./activities')

getOutputs <- function(FILEPATH, DISTANCE=5){
  #check file type (gpx or tmx)
  filekind = substr(FILEPATH, nchar(FILEPATH)-3, nchar(FILEPATH))
  #read in the file, this automatically calculated distance from the lat/long coords
  if (filekind == ".gpx") {
    runDF <- readGPX(FILEPATH, timezone = "GMT")
  } else if (filekind == ".tcx") {
    runDF <- readTCX(FILEPATH, timezone = "GMT")
  } else {
    print("FILE NOT SUPPORTED")
  } 
  
  #check date of submission
  timestamp = runDF$time[1]
  datetime = ymd_hms(timestamp)
  print(datetime)
  
  # calculate point-to-point distance using the cumulative distance (distance)
  runDF$dist_point <- c(0,diff(runDF$distance, lag=1)) 
  # calculate point-to-point elevation change 
  runDF$alti_point <- c(0,diff(runDF$altitude, lag=1))
  # calculate the point-to-point gradient as a percentage
  runDF$grad_point <- (runDF$alti_point / runDF$dist_point) * 100
  
  #DONT KNOW WHY BUT THE BELOW DOESNT WORK FOR ALL FILES AND STOPS FUNCTION
  #check for and eliminate gradients above or below 20
  #which are not evaluated by the formula
  #index_to_remove = which(runDF$grad_point > 40 | runDF$grad_point < -40)
  #runDF <- runDF[-index_to_remove,]
  
  # time calculations
  runDF$time_temp <- strptime(runDF$time, format = "%Y-%m-%d %H:%M:%S") #CONVERTS TO POSIXlt
  runDF$time_point <- c(0,diff(as.vector(runDF$time_temp), lag=1)) #GETS TIME LENGTHS IN SECONDS
  runDF$time_temp <- NULL
  runDF$time_cumulative <- cumsum(runDF$time_point) #CUMULATIVE SECONDS
  runDF$time_hms <- as_hms(runDF$time_cumulative)
  
  # speed in m/s
  runDF$speed <- runDF$dist_point / runDF$time_point
  
  #FORMULA ADJUSTS DISTANCE AS A FUNCTION OF GRADIENT 
  #pulled from strava graph, adjusted to calculate speed
  #https://quantixed.org/2020/05/19/running-free-calculating-efficiency-factor-in-r/
  #calculate the normalized graded speed
  runDF$ngs <- runDF$speed * (0.98462 + (0.030266 * runDF$grad_point) + 
                                (0.0018814 * runDF$grad_point ^ 2) + 
                                (-3.3882e-06 * runDF$grad_point ^ 3) + 
                                (-4.5704e-07 * runDF$grad_point ^ 4))
  
  #ALSO MUST CONVERT ALL "Inf" VALUES
  runDF$ngs[is.infinite(runDF$ngs)] <- NA
  runDF$speed[is.infinite(runDF$speed)] <- NA
  # replace NaNs with 0
  runDF[is.na(runDF)] <- 0
  
  #cut off based on distance
  distanceKM = DISTANCE * 1000
  #get row for cutoff point
  #check if file is long enough:
  lastRow = min(which(runDF$distance > distanceKM))
  if (is.infinite(lastRow)){
    #print("bad")
    lastRow <- nrow(runDF)
  } else { #cut dataframe
    runDF <- runDF[1:lastRow,]
    #print("good")
  }
  
  #calculate average ngs
  runDF$weightedNGS <- runDF$ngs * runDF$time_point
  adjustedPace = sum(runDF$weightedNGS) / runDF$time_cumulative[lastRow] 
  
  #calculate average speed
  runDF$weightedSPEED <- runDF$speed * runDF$time_point
  actualPace = sum(runDF$weightedSPEED) / runDF$time_cumulative[lastRow]
  
  #calculate elevation
  runDF$absAlt <- abs(runDF$alti_point)
  runDF$cumAltChange <- cumsum(runDF$absAlt)
  elevation = runDF$cumAltChange[lastRow] 
  
  #calculate adjusted race time in minutes
  adjustedTime = (distanceKM / adjustedPace) / 60
  
  #calculate actual race time in minutes
  actualTime = (distanceKM / actualPace) / 60
  
  #get latitude and longitude coordinates for maps
  longitude <- runDF$longitude[1]
  latitude <- runDF$latitude[1]
  
  my_list = list(adjustedPace, actualPace, elevation, adjustedTime, actualTime, longitude, latitude, datetime) 
  #string = paste(adjustedPace, actualPace, elevation, adjustedTime, actualTime, longitude, latitude, sep=",")
  return(my_list) # , adjustedTime, actualTime) #, longitude, latitude)
  #return(adjustedPace, actualPace, elevation, adjustedTime, actualTime, longitude, latitude)
}

#create empty dataframe for outputs
outputsDF <- data.frame(matrix(ncol = 8, nrow = 0))
names <- c("adjustedPace", "actualPace", "elevation", "adjustedTime", "actualTime", "longitude", "latitude", "datetime")
colnames(outputsDF) <- names

#list of file names in the activities folder
files = list.files(pattern="*.gpx")

#fill dataframe with outputs
for (i in 1:length(files)){
  values_list = getOutputs(files[i])
  #print(length(values_list))
  for (j in 1:length(values_list)){
    outputsDF[i,j] <- as.numeric(values_list[j])
  }
}


outputsDF$datetime <- as.POSIXct(outputsDF$datetime, origin = "1970-01-01")
setwd('5kRun')
write.csv(outputsDF, "activities.outputs.csv", row.names=FALSE)


#get lat/long and datetime only for viz
lat_long <- outputsDF[,c(6:8)]
write.csv(lat_long, "long_lat_date.csv", row.names=FALSE)
