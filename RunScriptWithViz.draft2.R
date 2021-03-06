library(trackeR)
library(zoo)
library(hms)
library(ggplot2)


FILEPATH = '29_not athletic 2.gpx' #adjust as needed
DISTANCE = 5 #5, 10 or 15km

#check file type (gpx or tmx)
filekind = substr(FILEPATH, nchar(FILEPATH)-3, nchar(FILEPATH))
#read in the file, this automatically calculated distance from the lat/long coords
if (filekind == ".gpx") {
  runDF <- readGPX(FILEPATH, timezone = "GMT")
} else if (filekind == ".tmx") {
  runDF <- readGPX(FILEPATH, timezone = "GMT")
} else {
  print("FILE NOT SUPPORTED")
} 

# calculate point-to-point distance using the cumulative distance (distance)
runDF$dist_point <- c(0,diff(runDF$distance, lag=1)) 
# calculate point-to-point elevation change 
runDF$alti_point <- c(0,diff(runDF$altitude, lag=1))
# calculate the point-to-point gradient as a percentage
runDF$grad_point <- (runDF$alti_point / runDF$dist_point) * 100

# QUICK VISUALIZATIONS
# altitudinal change with distance
ggplot(runDF, aes(x=distance, y=altitude)) +
  geom_line()

# gradient chance with distance
ggplot(runDF, aes(x=distance, y=grad_point)) +
  geom_line()

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
#VISUALIZE THE FORMULA FROM STRAVA
x <- seq(-30,30, by=2)
y <- 1 *
  (0.98462 + (0.030266 * x) + 
     (0.0018814 * x ^ 2) + 
     (-3.3882e-06 * x ^ 3) + 
     (-4.5704e-07 * x ^ 4))
#MULTIPLY BY DIST OF 1 = EXACT PACE ADJUSTMENT
#if speed is 1, gradient is 0: normalized speed = 1
#if speed is 1, gradient is -30: normalized speed is 1*1.5 = 1.5

baseline <- as.data.frame(cbind(x,y))
ggplot(baseline, aes(x=x, y=y)) +
  geom_line(color = "red") +
  geom_point(color = "red") +
  xlab("Gradient") +
  ylab("Pace Adjustment")

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
lastRow = min(which(runDF$distance > distanceKM))
#cut dataframe
runDF <- runDF[1:lastRow,]

#calculate average ngs
runDF$weightedNGS <- runDF$ngs * runDF$time_point
adjustedPace = mean(runDF$weightedNGS)

#calculate average speed
runDF$weightedSPEED <- runDF$speed * runDF$time_point
actualPace = mean(runDF$weightedSPEED)

#calculate elevational change
runDF$absAlt <- abs(runDF$alti_point)
runDF$cumAltChange <- cumsum(runDF$absAlt)
elevation = runDF$cumAltChange[lastRow] 

#calculate adjusted race time in minutes
adjustedTime = (distanceKM / adjustedPace) / 60

#calculate actual race time in minutes
actualTime = (distanceKM / actualPace) / 60

print(paste("Normalized Speed is", adjustedPace, "m/s"))
print(paste("Actual Speed is", actualPace, "m/s"))
print(paste("Absolute Elevational Change is", elevation, "m"))
print(paste("Normalized Race Time is", adjustedTime, "minutes"))
print(paste("Actual Race Time is", actualTime, "minutes"))