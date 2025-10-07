# GStreamer source download - cached independently
{ pkgs, config }:

pkgs.fetchurl {
  url = config.gstreamerUrl config.gstreamerVersion;
  sha256 = config.gstreamerSha256;

  # Add metadata
  meta = {
    description = "GStreamer ${config.gstreamerVersion} for Android";
    homepage = "https://gstreamer.freedesktop.org";
  };
}