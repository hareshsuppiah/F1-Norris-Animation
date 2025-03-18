###############################################################################
## 1. Setup and Package Loading
###############################################################################

# install.packages("f1dataR")   # Uncomment if you haven't installed f1dataR yet
# install.packages("dplyr")
# install.packages("ggplot2")
# install.packages("gganimate")
# install.packages("gifski")
# install.packages("ggrepel")

library(f1dataR)
library(dplyr)
library(ggplot2)
library(gganimate)
library(gifski)
library(ggrepel)


###############################################################################
## 2. Load Qualifying Results (for reference; helps confirm driver codes, etc.)
###############################################################################

quali_results_2025 <- load_quali(
  season = 2025,
  round  = 1
)

dplyr::glimpse(quali_results_2025)

###############################################################################
## 3. Load Lap-by-Lap Data (Qualifying Session) and Filter for Lando Norris
###############################################################################

clear_f1_cache() # This may be needed if there's a known cache conflict in your environment

# Load all lap data from the qualifying session
# This returns detailed lap info for every driver
session_laps_q <- load_session_laps(
  season  = 2025,
  round   = 1,
  session = "Q"
)

# Identify best lap time for Norris specifically
# The 'driver' column in session_laps_q uses 3-letter codes like "NOR"
norris_best_lap <- session_laps_q %>%
  filter(driver == "NOR") %>%        # Keep only Norris
  slice_min(order_by = lap_time, n = 1, with_ties = FALSE) %>%
  select(lap_number) %>%
  pull(lap_number)

cat("Norris's fastest qualifying lap is Lap:", norris_best_lap, "\n")

###############################################################################
## 4. Load Detailed Telemetry for Norris's Best Lap
###############################################################################

norris_telemetry <- load_driver_telemetry(
  season  = 2025,
  round   = 1,
  session = "Q",
  driver  = "NOR",
  laps    = norris_best_lap
)

# We'll store it in a data frame with an added column indicating the driver
all_telemetry_df <- norris_telemetry %>%
  mutate(driver_code = "NOR")

# Optional glance at the columns available
# dplyr::glimpse(all_telemetry_df)

###############################################################################
## 5. Load Track Corner Data for the Relevant Circuit
##    Used 2024 Round 3 (Melbourne) info here because 2025 data wasn’t posted yet.
##    This is just to illustrate corner markers in the final animation.
###############################################################################

circuit_info <- load_circuit_details(
  season   = 2024,
  round    = 3, 
  log_level = "WARNING"
)

# Extract corner information into a data frame
corners_df <- circuit_info$corners %>%
  # Create a nicer label combining corner number + letter
  mutate(
    corner_label = ifelse(
      letter == "",
      as.character(number),
      paste0(number, letter)
    )
  )

###############################################################################
## 6. Animate Norris's Lap
##    We'll create a line plot of Speed vs. Distance along the lap,
##    then animate it so a point moves in sync with Norris's real telemetry.
###############################################################################

# Filter the combined telemetry for Norris only (redundant, but clear for demonstration)
norris_df <- all_telemetry_df %>%
  filter(driver_code == "NOR")

# 1. Calculate total duration of Norris's fastest lap in seconds
lap_duration <- max(norris_df$time, na.rm = TRUE) 
cat("Lap duration (sec):", lap_duration, "\n")

# 2. Decide animation parameters
fps     <- 20  # frames per second
nframes <- round(lap_duration * fps)  # total number of frames

# 3. Create the base plot
synced_plot <- ggplot(norris_df, aes(x = distance, y = speed)) +
  # Draw speed trace
  geom_line(size = 1, color = "blue") +
  # Add points
  geom_point(size = 3, color = "blue") +
  # Add vertical lines for each corner
  geom_vline(
    data     = corners_df,
    aes(xintercept = distance),
    color    = "grey40",
    linetype = "dashed",
    alpha    = 0.7
  ) +
  # Add corner labels using ggrepel
  geom_text_repel(
    data          = corners_df,
    aes(x = distance, y = 90, label = corner_label),
    color         = "black",
    angle         = 90,
    size          = 3,
    nudge_y       = 10,            # shift label above plot lines
    segment.color = "transparent"  # no line from label to corner
  ) +
  labs(
    title    = "Norris' Fastest Qualifying Lap",
    subtitle = "Blue dot moves according to real telemetry speeds",
    x        = "Distance (m)",
    y        = "Speed (km/h)"
  ) +
  theme_minimal(base_size = 14)

# 4. Convert static plot to an animation (time-based reveal)
animated_synced_plot <- synced_plot +
  transition_reveal(along = time) +  # let time control the sequential "reveal"
  ease_aes("linear")

# 5. Render the animation
synced_anim <- animate(
  animated_synced_plot,
  nframes  = nframes,
  fps      = fps,
  width    = 800,
  height   = 600,
  renderer = gifski_renderer() # produces a .gif
)

# 6. Display the animation in RStudio's viewer or notebook
synced_anim

# 7. (Optional) Save to file
anim_save("norris_qualilap.gif", animation = synced_anim)
