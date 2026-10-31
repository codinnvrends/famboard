# ML Kit text recognition: the plugin references every script's options
# class, but FamBoard only ships the Latin and Devanagari models.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
