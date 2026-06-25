// public/inventory/vehicle_details_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VehicleDetailsPage extends StatefulWidget {
  final String carId;

  const VehicleDetailsPage({
    super.key,
    required this.carId,
  });

  @override
  State<VehicleDetailsPage> createState() =>
      _VehicleDetailsPageState();
}

class _VehicleDetailsPageState
    extends State<VehicleDetailsPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;

  Map<String, dynamic>? car;
  List<Map<String, dynamic>> images = [];
  List<Map<String, dynamic>> relatedCars = [];

  String selectedImage = '';

  @override
  void initState() {
    super.initState();
    loadVehicle();
  }

  Future<void> loadVehicle() async {
    try {
      final vehicle = await supabase
          .from('cars')
          .select()
          .eq('id', widget.carId)
          .single();

      final vehicleImages = await supabase
          .from('car_images')
          .select()
          .eq('car_id', widget.carId);

      car = vehicle;

      images =
          List<Map<String, dynamic>>.from(vehicleImages);

      if (images.isNotEmpty) {
        final primary = images.firstWhere(
          (e) => e['is_primary'] == true,
          orElse: () => images.first,
        );

        selectedImage = primary['image_url'];
      }

      final related = await supabase
          .from('cars')
          .select()
          .eq('make', car!['make'])
          .neq('id', widget.carId)
          .limit(4);

      relatedCars =
          List<Map<String, dynamic>>.from(related);
    } catch (e) {
      debugPrint(e.toString());
    }

    setState(() => loading = false);
  }

  Future<void> addToFavorites() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      Navigator.pushNamed(
        context,
        '/login',
        arguments: {
          'redirect': '/vehicle-details',
          'carId': widget.carId,
        },
      );
      return;
    }

    await supabase.from('favorites').insert({
      'user_id': user.id,
      'car_id': widget.carId,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vehicle added to favorites',
          ),
        ),
      );
    }
  }

  Future<void> reserveVehicle() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      Navigator.pushNamed(
        context,
        '/login',
        arguments: {
          'redirect': '/reserve-vehicle',
          'carId': widget.carId,
        },
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/reserve-vehicle',
      arguments: car,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${car?['make']} ${car?['model']}',
        ),
        actions: [
          IconButton(
            onPressed: addToFavorites,
            icon: const Icon(Icons.favorite_border),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // MAIN IMAGE

            AspectRatio(
              aspectRatio: 16 / 9,
              child: selectedImage.isNotEmpty
                  ? Image.network(
                      selectedImage,
                      fit: BoxFit.cover,
                    )
                  : const Icon(
                      Icons.directions_car,
                      size: 100,
                    ),
            ),

            // THUMBNAILS

            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (_, index) {
                  final image = images[index];

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedImage =
                            image['image_url'];
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      width: 100,
                      child: Image.network(
                        image['image_url'],
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    '${car?['make']} ${car?['model']}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Text(
                    '${car?['year']}',
                  ),

                  const SizedBox(height: 12),

                  Text(
                    '\$${car?['sale_price'] ?? car?['price']}',
                    style: const TextStyle(
                      fontSize: 32,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Specifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _spec(
                          'Mileage',
                          '${car?['mileage']} km'),
                      _spec(
                          'Fuel',
                          '${car?['fuel_type']}'),
                      _spec(
                          'Transmission',
                          '${car?['transmission']}'),
                      _spec(
                          'Engine',
                          '${car?['engine']}'),
                      _spec(
                          'Body',
                          '${car?['body_type']}'),
                      _spec(
                          'Seats',
                          '${car?['seats']}'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    car?['full_description'] ?? '',
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: reserveVehicle,
                      child: const Text(
                        'Reserve Vehicle',
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/inquiry',
                          arguments: car,
                        );
                      },
                      child: const Text(
                        'Send Inquiry',
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    'Related Vehicles',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    height: 260,
                    child: ListView.builder(
                      scrollDirection:
                          Axis.horizontal,
                      itemCount: relatedCars.length,
                      itemBuilder: (_, index) {
                        final related =
                            relatedCars[index];

                        return Card(
                          child: SizedBox(
                            width: 220,
                            child: ListTile(
                              title: Text(
                                '${related['make']} ${related['model']}',
                              ),
                              subtitle: Text(
                                '\$${related['price']}',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _spec(String title, String value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}