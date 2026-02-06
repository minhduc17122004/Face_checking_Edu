import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'styles/text_styles.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: Colors.blue,
      primaryColor: AppColors.blue,
      scaffoldBackgroundColor: AppColors.white,
      
      // App bar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      
      // Input field theme
      inputDecorationTheme: InputDecorationTheme(
        // Border when not focused
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.gray100, width: 1),
        ),
        // Border when enabled but not focused
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.gray100, width: 1),
        ),
        // Border when focused
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.blue, width: 2),
        ),
        // Border when there's an error
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.red, width: 1),
        ),
        // Border when focused and there's an error
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.red, width: 2),
        ),
        // Content padding
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        // Fill color
        filled: true,
        fillColor: AppColors.white,
        // Hint text style
        hintStyle: const TextStyle(
          color: AppColors.gray200,
          fontSize: 14,
        ),
        // Label text style
        labelStyle: const TextStyle(
          color: AppColors.gray200,
          fontSize: 14,
        ),
        // Floating label style when focused
        floatingLabelStyle: const TextStyle(
          color: AppColors.blue,
          fontSize: 16,
        ),
        // Error text style
        errorStyle: const TextStyle(
          color: AppColors.red,
          fontSize: 12,
        ),
      ),
      
      // Radio button theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.blue;
          }
          return AppColors.gray200;
        }),
        overlayColor: WidgetStateProperty.all(AppColors.blue.withAlpha(10)),
        splashRadius: 20,
      ),
      
      // Checkbox theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.blue;
          }
          return AppColors.white;
        }),
        checkColor: WidgetStateProperty.all(AppColors.white),
        overlayColor: WidgetStateProperty.all(AppColors.blue.withOpacity( 0.1)),
        splashRadius: 20,
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const BorderSide(color: AppColors.blue, width: 2);
          }
          return const BorderSide(color: AppColors.gray200, width: 2);
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      
      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: AppColors.white,
          elevation: 2,
          shadowColor: AppColors.blue.withOpacity( 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.blue,
          side: const BorderSide(color: AppColors.blue, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      // Date picker theme
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.white,
        headerBackgroundColor: AppColors.blue,
        headerForegroundColor: AppColors.white,
        dayForegroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.white;
          }
          return AppColors.black;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.blue;
          }
          return Colors.transparent;
        }),
        todayForegroundColor: WidgetStateProperty.all(AppColors.blue),
        todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
        todayBorder: const BorderSide(color: AppColors.blue, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      // Time picker theme
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        // Header styling (AM/PM and title)
        helpTextStyle: TextStyles.blackNormalBold.copyWith(
          color: AppColors.blue,
          fontSize: 16,
        ),
        hourMinuteTextStyle: TextStyles.blackNormalBold.copyWith(
          color: AppColors.blue,
          fontSize: 32,
        ),
        // Hour/Minute containers
        hourMinuteShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.blue, width: 2),
        ),
        hourMinuteColor: AppColors.blue.withOpacity( 0.1),
        // Day period (AM/PM) styling
        dayPeriodTextStyle: TextStyles.blackNormalBold.copyWith(
          color: AppColors.blue,
          fontSize: 14,
        ),
        dayPeriodShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.blue, width: 1),
        ),
        dayPeriodColor: AppColors.blue.withOpacity( 0.05),
        dayPeriodBorderSide: const BorderSide(color: AppColors.blue),
        // Dial styling
        dialHandColor: AppColors.blue,
        dialBackgroundColor: AppColors.blue.withOpacity( 0.1),
        dialTextColor: AppColors.black,
        entryModeIconColor: AppColors.blue,
        // Cancel/OK buttons
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.gray200,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        confirmButtonStyle: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // Icon theme
      iconTheme: const IconThemeData(
        color: AppColors.gray200,
        size: 24,
      ),
      
      // Text selection theme
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.black,
        selectionColor: AppColors.black.withOpacity( 0.2),
        selectionHandleColor: AppColors.black,
      ),
      
      // List tile theme
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.zero,
        dense: true,
        horizontalTitleGap: 8,
        iconColor: AppColors.gray200,
        textColor: AppColors.black,
      ),
      

      
      // Bottom navigation bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.blue,
        unselectedItemColor: AppColors.gray200,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
      ),
      
      // Snack bar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.black,
        contentTextStyle: const TextStyle(color: AppColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
      
      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.blue,
        linearTrackColor: AppColors.gray100,
        circularTrackColor: AppColors.gray100,
      ),
      
      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.blue;
          }
          return AppColors.gray200;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.blue.withOpacity( 0.5);
          }
          return AppColors.gray100;
        }),
      ),
      
      // Slider theme
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.blue,
        inactiveTrackColor: AppColors.gray100,
        thumbColor: AppColors.blue,
        overlayColor: AppColors.blue.withOpacity( 0.2),
        valueIndicatorColor: AppColors.blue,
        valueIndicatorTextStyle: const TextStyle(color: AppColors.white),
      ),
      
      // Divider theme
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerColor,
        thickness: 1,
        space: 1,
      ),
      
   
      
      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.gray100,
        deleteIconColor: AppColors.gray200,
        disabledColor: AppColors.gray100,
        selectedColor: AppColors.blue.withOpacity( 0.2),
        secondarySelectedColor: AppColors.blue,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: const TextStyle(color: AppColors.black),
        secondaryLabelStyle: const TextStyle(color: AppColors.white),
        brightness: Brightness.light,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
  
  // You can add a dark theme here in the future
  static ThemeData get darkTheme {
    // Return a dark theme configuration if needed
    return lightTheme; // Placeholder for now
  }
}