import 'package:flutter/material.dart';

class UserInfoCard extends StatelessWidget {
  final String title;
  final List<List<String>> items;

  const UserInfoCard({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            Divider(),
            ...items.map(
              (item) => Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item[0],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(item[1]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
