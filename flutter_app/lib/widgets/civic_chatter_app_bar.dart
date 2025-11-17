import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CivicChatterAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;

  const CivicChatterAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Civic Chatter Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Center(
            child: Text(
              'Civic Chatter',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
          ),
        ),
        // Navigation Bar
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              if (showBackButton && Navigator.of(context).canPop())
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Back',
                ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          icon: Icon(Icons.home,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurface),
                          label: Text('Home',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface)),
                          onPressed: () => context.go('/home'),
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          icon: Icon(Icons.gavel,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurface),
                          label: Text('Debates',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface)),
                          onPressed: () => context.go('/debates'),
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          icon: Icon(Icons.person,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurface),
                          label: Text('My Profile',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface)),
                          onPressed: () => context.go('/profile'),
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          icon: Icon(Icons.settings,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurface),
                          label: Text('Settings',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface)),
                          onPressed: () => context.go('/settings'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
        ),
        // Page Title
        AppBar(
          title: Text(title),
          automaticallyImplyLeading: false,
          centerTitle: true,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(138);
}
