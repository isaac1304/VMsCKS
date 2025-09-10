provider "google" {
  project     = "tidy-simplicity-359100"
  region      = "us-central1"
  credentials = file("${path.module}/key.json")
}
