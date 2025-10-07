{ extendedPkgs, gstreamerAndroid }:

# Combine all packages
gstreamerAndroid.packages ++
(with extendedPkgs; [
  # Add any additional packages here
])