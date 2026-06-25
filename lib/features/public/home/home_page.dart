// public/home/home_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/vehicle_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;

  bool loading = true;

  List<Map<String, dynamic>> featuredCars = [];
  List<Map<String, dynamic>> latestCars = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      setState(() => loading = true);

      final featured = await supabase
          .from('cars')
          .select()
          .eq('featured', true)
          .eq('status', 'available')
          .limit(6);

      final latest = await supabase
          .from('cars')
          .select()
          .eq('status', 'available')
          .order('created_at', ascending: false)
          .limit(12);

      featuredCars =
          List<Map<String, dynamic>>.from(featured);

      latestCars =
          List<Map<String, dynamic>>.from(latest);
    } catch (e) {
      debugPrint(e.toString());
    }

    setState(() => loading = false);
  }

  Future<void> toggleFavorite(
      Map<String, dynamic> car) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      Navigator.pushNamed(
        context,
        '/login',
        arguments: {
          'redirect': '/home',
        },
      );
      return;
    }

    await supabase.from('favorites').insert({
      'user_id': user.id,
      'car_id': car['id'],
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to favorites'),
        ),
      );
    }
  }

  void openVehicle(Map<String, dynamic> car) {
    Navigator.pushNamed(
      context,
      '/vehicle-details',
      arguments: car,
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: loadData,
              child: ListView(
                children: [
                  // HERO

                  Container(
                    height: 300,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(
                          'assets/images/welcome_bg.jpeg',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Image.asset(
                             'assets/images/meridian_logo.png',
                            height: 80,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Find Your Dream Car',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/inventory',
                              );
                            },
                            child: const Text(
                              'Browse Inventory',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  sectionTitle('Featured Vehicles'),

                  SizedBox(
                    height: 420,
                    child: ListView.builder(
                      scrollDirection:
                          Axis.horizontal,
                      itemCount: featuredCars.length,
                      itemBuilder: (_, index) {
                        final car =
                            featuredCars[index];

                        return SizedBox(
                          width: 320,
                          child: VehicleCard(
                            car: car,
                            onTap: () =>
                                openVehicle(car),
                            onFavorite: () =>
                                toggleFavorite(car),
                          ),
                        );
                      },
                    ),
                  ),

                  sectionTitle('Latest Vehicles'),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      itemCount: latestCars.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: .75,
                      ),
                      itemBuilder: (_, index) {
                        final car =
                            latestCars[index];

                        return VehicleCard(
                          car: car,
                          onTap: () =>
                              openVehicle(car),
                          onFavorite: () =>
                              toggleFavorite(car),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 30),

                  Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.black,
                    child: const Column(
                      children: [
                        Text(
                          'Meridian Motors',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Quality Cars. Trusted Service.',
                          style: TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}