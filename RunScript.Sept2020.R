
library(trackeR)
library(zoo)
library(hms)
library(lubridate)

getAdjustedPace <- function(FILEPATH, DISTANCE){
  #check file type (gpx or tcx)
  filekind = substr(FILEPATH, nchar(FILEPATH)-3, nchar(FILEPATH))
  #read in the file, this automatically calculated distance from the lat/long coords
  if (filekind == ".gpx") {
    runDF <- readGPX(FILEPATH, timezone = "GMT")
  } else if (filekind == ".tcx") {
    runDF <- readTCX(FILEPATH, timezone = "GMT")
  } else {
    string = paste("FALSE", "FILE TYPE NOT SUPPORTED", sep=",")
    return(string)
  } 
  
  #check date of submission
  timestamp = runDF$time[1]
  datetime = ymd_hms(timestamp) 
  start_datetime = ymd_hms("2020_10_11 00:00:00")
  end_datetime = ymd_hms("2020_10_18 23:59:59")
  if (datetime < start_datetime | datetime > end_datetime){
    string = paste("FALSE", "SUBMISSION FROM OUTSIDE RACE TIME WINDOW", sep =",")
    return(string)
  }
  
  # calculate point-to-point distance using the cumulative distance (distance)
  runDF$dist_point <- c(0,diff(runDF$distance, lag=1)) 
  # calculate point-to-point elevation change 
  runDF$alti_point <- c(0,diff(runDF$altitude, lag=1))
  # calculate the point-to-point gradient as a percentage
  runDF$grad_point <- (runDF$alti_point / runDF$dist_point) * 100
  
  #check for and eliminate gradients that are outside the range covered
  #by the Strava polynomial formula (and potential GPS glitches if extreme gradients)
  index_to_remove = which(runDF$grad_point > 40  | runDF$grad_point < -40)
  #handle only if there are values to remove
  if (length(index_to_remove) > 0){
    runDF <- runDF[-index_to_remove,]
  }
  
  #if the above results in some rows being removed
  #the below code assumes that the gradient remains the same for the 
  #newly calculated time differences (where rows were skipped, time_point is longer)
  # time calculations
  runDF$time_temp <- strptime(runDF$time, format = "%Y-%m-%d %H:%M:%S") #CONVERTS TO POSIXlt
  runDF$time_point <- c(0,diff(as.vector(runDF$time_temp), lag=1)) #GETS TIME LENGTHS IN SECONDS
  runDF$time_temp <- NULL
  runDF$time_cumulative <- cumsum(runDF$time_point) #CUMULATIVE SECONDS
  runDF$time_hms <- as_hms(runDF$time_cumulative) #keep this in case we need to compare calculated vs recorded race times
  
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
  distanceM = DISTANCE * 1000
  #get row for cutoff point
  
  #check if distance is too short
  #and if not, cut data to correct distance 
  if (is.infinite(min(which(runDF$distance > distanceM)))){
    string = paste("FALSE", "RUN DISTANCE TOO SHORT", sep=",")
    return(string)
  } else { 
    #cut dataframe to correct length 
    #(as close as possible)
    lastRow = min(which(runDF$distance > distanceM))
    runDF <- runDF[1:lastRow,]
  }
  
  #Below: calculation this way enables us to account for slightly different
  #race times (cut as close to 5KM as possible but not all will be the same)
  #here we get mean speed and mean normalizad graded speed over individual race time, 
  #which we then convert to actual time given hardcoded distance of 5KM
  
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
  adjustedTime = (distanceM / adjustedPace) / 60
  
  #calculate actual race time in minutes
  actualTime = (distanceM / actualPace) / 60
  
  #check for speeds too fast
  #for 5k world record is 12.6 minutes for males
  #for 10k world record is 26.28 minutes for males 
  #for 15k world record is 41.08 minutes for males 
  if (DISTANCE == 5){
    if (actualTime < 12.6){
      string = paste("FALSE", "FASTER THAN 5K WORLD RECORD", sep=',')
      return(string)
    }
  }else if (DISTANCE == 10){
    if (actualTime < 26.28){
      string = paste("FALSE", "FASTER THAN 10K WORLD RECORD", sep=',')
      return(string)  
    }
  }else { #distance is 15km here
    if (actualTime < 41.08){
      string = paste("FALSE", "FASTER THAN 15K WORLD RECORD", sep=',')
      return(string)
    }
  }
    
  #get latitude and longitude coordinates for maps
  longitude <- runDF$longitude[1]
  latitude <- runDF$latitude[1]
  
  #return ngs, actual pace, elevation as csv
  string = paste("TRUE", adjustedPace, actualPace, elevation, adjustedTime, actualTime, longitude, latitude, datetime, sep=",")
  return(string)
}


FILEPATH = '29_not athletic 2.gpx' #adjust as needed
DISTANCE = 5 #5, 10 or 15km
print(getAdjustedPace(FILEPATH, DISTANCE))
