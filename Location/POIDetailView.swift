import SwiftUI
import MapKit
import CoreLocation

struct POIDetailView: View {
    let poi: POI
    let userLocation: CLLocation?
    
    // Callback to pass back the calculated route.
    var onShowRoute: ((MKRoute) -> Void)?
    
    // State for estimated travel time, route distance, and loading/error states.
    @State private var estimatedTravelTime: TimeInterval?
    @State private var routeDistance: Double?
    @State private var isLoadingRoute: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    // Picker for travel mode (Driving and Walking only).
    @State private var selectedTravelModeRaw: UInt = MKDirectionsTransportType.automobile.rawValue
    var selectedTravelMode: MKDirectionsTransportType {
        get { MKDirectionsTransportType(rawValue: selectedTravelModeRaw) }
        set { selectedTravelModeRaw = newValue.rawValue }
    }
    
    @Environment(\.presentationMode) var presentationMode
    
    // Straight‑line (geometric) distance.
    var straightLineDistance: Double? {
        guard let userLocation = userLocation else { return nil }
        let poiLocation = CLLocation(latitude: poi.coordinate.latitude,
                                     longitude: poi.coordinate.longitude)
        return userLocation.distance(from: poiLocation)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if !poi.imageName.isEmpty {
                        Image(poi.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(10)
                            .padding()
                            .shadow(radius: 5)
                            .transition(.opacity)
                    }
                    
                    Text(poi.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .transition(.move(edge: .top))
                    Text(poi.description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if let d = straightLineDistance {
                        Text(String(format: "Straight-line Distance: %.0f meters", d))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    } else {
                        Text("User location not available")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Picker("Travel Mode", selection: $selectedTravelModeRaw) {
                        Text("Driving").tag(MKDirectionsTransportType.automobile.rawValue)
                        Text("Walking").tag(MKDirectionsTransportType.walking.rawValue)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .onChange(of: selectedTravelModeRaw) {
                        calculateRouteAndTime()
                    }
                    
                    if let travelTime = estimatedTravelTime,
                       let rDistance = routeDistance {
                        VStack(spacing: 5) {
                            Text("Estimated Travel Time: \(formatTravelTime(travelTime))")
                                .font(.subheadline)
                            Text(String(format: "Route Distance: %.0f meters", rDistance))
                                .font(.subheadline)
                        }
                        .transition(.opacity)
                        .animation(.easeInOut, value: estimatedTravelTime)
                    }
                    
                    if isLoadingRoute {
                        ProgressView("Calculating Route...")
                            .padding()
                            .transition(.opacity)
                    }
                    
                    VStack(spacing: 12) {
                        Button(action: {
                            openMapsForDirections()
                        }) {
                            Text("Open In Apple Maps")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        
                        Button(action: {
                            calculateRoute { route in
                                if let route = route {
                                    onShowRoute?(route)
                                    presentationMode.wrappedValue.dismiss()
                                } else {
                                    errorMessage = "Unable to calculate route."
                                    showErrorAlert = true
                                }
                            }
                        }) {
                            Text("Show Route In-App")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("POI Details")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                withAnimation(.easeInOut) {
                    calculateRouteAndTime()
                }
            }
            .alert(isPresented: $showErrorAlert) {
                Alert(title: Text("Error"),
                      message: Text(errorMessage),
                      dismissButton: .default(Text("OK")))
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Route and Time Calculation Methods
    
    func calculateRouteAndTime() {
        guard let userLocation = userLocation else {
            estimatedTravelTime = nil
            routeDistance = nil
            return
        }
        withAnimation(.easeInOut) { isLoadingRoute = true }
        let sourcePlacemark = MKPlacemark(coordinate: userLocation.coordinate)
        let destinationPlacemark = MKPlacemark(coordinate: poi.coordinate)
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destinationPlacemark)
        request.transportType = selectedTravelMode
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            withAnimation(.easeInOut) {
                isLoadingRoute = false
            }
            if let error = error {
                print("Error calculating route: \(error.localizedDescription)")
                estimatedTravelTime = nil
                routeDistance = nil
                return
            }
            if let route = response?.routes.first {
                estimatedTravelTime = route.expectedTravelTime
                routeDistance = route.distance
            }
        }
    }
    
    func calculateRoute(completion: @escaping (MKRoute?) -> Void) {
        guard let userLocation = userLocation else {
            completion(nil)
            return
        }
        let sourcePlacemark = MKPlacemark(coordinate: userLocation.coordinate)
        let destinationPlacemark = MKPlacemark(coordinate: poi.coordinate)
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destinationPlacemark)
        request.transportType = selectedTravelMode
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let error = error {
                print("Error calculating route: \(error.localizedDescription)")
                completion(nil)
                return
            }
            completion(response?.routes.first)
        }
    }
    
    func openMapsForDirections() {
        let destinationPlacemark = MKPlacemark(coordinate: poi.coordinate)
        let mapItem = MKMapItem(placemark: destinationPlacemark)
        mapItem.name = poi.name
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: travelModeString(for: selectedTravelMode)
        ]
        mapItem.openInMaps(launchOptions: launchOptions)
    }
    
    func travelModeString(for type: MKDirectionsTransportType) -> String {
        switch type {
        case .automobile:
            return MKLaunchOptionsDirectionsModeDriving
        case .walking:
            return MKLaunchOptionsDirectionsModeWalking
        default:
            return MKLaunchOptionsDirectionsModeDefault
        }
    }
    
    func formatTravelTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours) hr \(remainingMinutes) min"
        }
    }
}
