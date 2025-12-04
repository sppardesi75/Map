import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var locationHandler = LocationHandler()
    @State private var region = MKCoordinateRegion(
         center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
         span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedPOI: POI? = nil
    @State private var searchText: String = ""
    @State private var mapType: MKMapType = .standard
    @State private var currentRoute: MKRoute? = nil  // For in-app route overlay
    
    // Sample POIs
    let samplePOIs: [POI] = [
        POI(name: "City Park",
            description: "A beautiful park in the middle of the city.",
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            imageName: "park",
            category: "Recreation"),
        POI(name: "Museum",
            description: "An art museum featuring local artists.",
            coordinate: CLLocationCoordinate2D(latitude: 37.7858, longitude: -122.4010),
            imageName: "museum",
            category: "Culture"),
        POI(name: "Historic Site",
            description: "A famous landmark with rich history.",
            coordinate: CLLocationCoordinate2D(latitude: 37.7800, longitude: -122.4200),
            imageName: "historic",
            category: "History"),
        POI(name: "Coffee Shop",
            description: "Popular coffee shop with a cozy atmosphere.",
            coordinate: CLLocationCoordinate2D(latitude: 37.7680, longitude: -122.4290),
            imageName: "coffee",
            category: "Food"),
        POI(name: "Library",
            description: "A community library with a vast selection of books.",
            coordinate: CLLocationCoordinate2D(latitude: 37.7760, longitude: -122.4240),
            imageName: "library",
            category: "Education")
    ]
    
    // Filter POIs based on search text.
    var filteredPOIs: [POI] {
        if searchText.isEmpty {
            return samplePOIs
        } else {
            return samplePOIs.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .topTrailing) {
                // Custom MapView including in-app route overlay.
                MapView(region: $region,
                        mapType: mapType,
                        pois: filteredPOIs,
                        selectedPOI: $selectedPOI,
                        route: $currentRoute)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                
                // Show a loading indicator if no user location is yet available.
                if locationHandler.userLocation == nil && locationHandler.authStatus != .denied {
                    ProgressView("Acquiring Location...")
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.8))
                        )
                        .shadow(radius: 5)
                        .transition(.opacity)
                }
                
                VStack {
                    // Map type picker with a rounded, semi-transparent background.
                    Picker("", selection: $mapType) {
                        Text("Standard").tag(MKMapType.standard)
                        Text("Satellite").tag(MKMapType.satellite)
                        Text("Hybrid").tag(MKMapType.hybrid)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.8))
                    )
                    .padding(.horizontal)
                    .padding(.top, 50)
                    
                    // Search bar with rounded background and shadow.
                    TextField("Search POIs...", text: $searchText)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .padding(.horizontal)
                        .transition(.move(edge: .top))
                    
                    if !searchText.isEmpty {
                        // List of search results with smooth transition.
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(filteredPOIs) { poi in
                                    Button(action: {
                                        withAnimation {
                                            region.center = poi.coordinate
                                        }
                                        selectedPOI = poi
                                    }) {
                                        HStack {
                                            Text(poi.name)
                                                .font(.headline)
                                            Spacer()
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.white.opacity(0.95))
                                        )
                                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxHeight: 200)
                        .transition(.move(edge: .top))
                    }
                    
                    Spacer()
                }
                
                // Recenter button with polished style.
                Button(action: {
                    if let userLocation = locationHandler.userLocation {
                        withAnimation {
                            region.center = userLocation.coordinate
                        }
                    }
                }) {
                    Image(systemName: "location.fill")
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.blue.opacity(0.8))
                        )
                }
                .padding()
            }
            .navigationTitle("Location")
            // Sheet to show POIDetailView.
            .sheet(item: $selectedPOI) { poi in
                POIDetailView(poi: poi,
                              userLocation: locationHandler.userLocation,
                              onShowRoute: { route in
                                  withAnimation {
                                      currentRoute = route
                                  }
                              })
            }
            // Error alert for location failures.
            .alert(isPresented: Binding<Bool>(
                get: { locationHandler.locationError != nil },
                set: { newValue in
                    if !newValue { locationHandler.locationError = nil }
                }
            )) {
                Alert(title: Text("Location Error"),
                      message: Text(locationHandler.locationError ?? "Unknown error."),
                      dismissButton: .default(Text("OK")))
            }
            .onAppear {
                if let loc = locationHandler.userLocation {
                    withAnimation {
                        region.center = loc.coordinate
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
