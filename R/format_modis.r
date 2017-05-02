#' Preprocessing of all PhenoCam data into a format which can be ingested
#' by the optimization routines etc.
#'
#' @param path: a path to MODISTools MCD12Q2 phenology dates
#' @param direction: Increase (= default), Maximum, Decrease, Minimum
#' @param offset: offset of the time series in DOY (default = 264, sept 21)
#' @keywords phenology, model, preprocessing
#' @export
#' @examples

process.modis = function(path = ".",
                            direction = "Increase",
                            offset = 264){

  # helper function to process the data
  format_data = function(site, transition_files, path){

    # for all sites merge the transition dates if there are multiple files
    # after merging, download the corresponding daymet data and create
    # the parts of the final structured list containing data for further
    # processing

    # get individual sites form the filenames
    sites = unlist(lapply(strsplit(transition_files,"_"),"[[",1))
    transition_files_full = paste(path, transition_files,sep = "/")
    files = transition_files_full[which(sites == site)]

    # merge all transition date data
    modis_data = read.table(files, header = FALSE, sep = ",")

    # grab the site years from the product name
    years = unique(as.numeric(substring(modis_data[,8],2,5)))

    # grab the location of the site
    lat_lon = unlist(strsplit(as.character(modis_data[1,9]),"Lon"))
    lat = as.numeric(gsub("Lat","",lat_lon[1]))
    lon = as.numeric(lapply(strsplit(lat_lon[2],"Samp"),"[[",1))

    # throw out all data but gcc_90
    modis_data = modis_data[grep(direction, as.character(modis_data[,6])), 11:ncol(modis_data)]
    modis_data[modis_data == 32767] = NA
    modis_data = round(apply(modis_data, 1, median, na.rm = TRUE))

    # min and max range of the phenology data
    # -1 for min_year as we need data from the previous year for cold
    # hardening
    start_yr = min(years) - 1
    end_yr = max(years)

    # download daymet data for a given site
    daymet_data = daymetr::download.daymet(
      site = site,
      lat = lat,
      lon = lon,
      start_yr = 1980,
      end_yr = end_yr,
      internal = "data.frame",
      quiet = TRUE
    )$data

    # calculate the mean daily temperature
    daymet_data$tmean = (daymet_data$tmax..deg.c. + daymet_data$tmin..deg.c.)/2

    # calculate the long term daily mean temperature and realign it so the first
    # day will be sept 21th (doy 264) and the matching DOY vector
    ltm = as.vector(by(daymet_data$tmean, INDICES = list(daymet_data$yday), mean))
    ltm = c(ltm[offset:365],ltm[1:(offset - 1)])
    doy = c(offset:365,1:(offset - 1))

    # create output matrix (holding temperature)
    temperature = matrix(NA,
                         nrow = 365,
                         ncol = length(years))

    # create a matrix containing the mean temperature between
    # sept 21th in the previous year until sept 21th in
    # the current year (make this a function parameter)
    for (j in 1:length(years)) {
      temperature[,j] = subset(daymet_data, (year == (years[j] - 1) & yday >= offset)|
                          ( year == years[j] & yday < offset ) )$tmean
    }

    # finally select all the transition dates for model validation
    modis_doy = as.numeric(format(seq(as.Date("2001/1/1"),Sys.Date(), "days"),"%j"))
    phenophase = modis_doy[modis_data]

    # format the data
    data = list("location" = c(lat, lon),
                "doy" = doy,
                "Tm" = ltm,
                "transition_dates" = phenophase,
                "Ti" = temperature)

    # return the formatted data
    return(data) # fix re-use variables
  }

  # list all files in the referred path
  transition_files = list.files(path,"*_MCD12Q2.asc")

  # get individual sites form the filenames
  sites = unique(unlist(lapply(strsplit(transition_files,"_"),"[[",1)))

  # construct validation data using the helper function
  # format_data() above
  validation_data = lapply(sites, function(x) {
    format_data(site = x,
                transition_files = transition_files,
                path = path)
  })

  # rename list variables using the proper site names
  names(validation_data) = sites

  # Flatten nested structure for speed
  # 100x increase in speed by doing so
  # avoiding loops

  if(any(grepl("transition_dates",names(validation_data)))){

    l = ncol(validation_data$tmean)
    Li = unlist(daylength(validation_data$doy, validation_data$location[1])[1])
    validation_data$Li = matrix(rep(Li,l),length(Li),l)
    validation_data$location = matrix(rep(validation_data$location,l),
                                      2,
                                      ncol(validation_data$tmean),
                                      byrow = FALSE)

  } else {

    doy = validation_data[[1]]$doy
    Li = do.call("cbind",lapply(validation_data,function(x){
      l = ncol(x$tmean)
      Li = unlist(daylength(x$doy, x$location[1])[1])
      Li = matrix(rep(Li,l),length(Li),l)
    }))
    tmean = do.call("cbind",lapply(validation_data,function(x)x$tmean))
    transition_dates = as.vector(do.call("c",lapply(validation_data,function(x)x$transition)))
    site_names =

    # recreate the validation data structure (new format)
    validation_data = list("tmean" = tmean, "doy" = doy, "Li"=Li, "transition" = transition_dates)
  }

  # return the formatted data
  return(validation_data)
}