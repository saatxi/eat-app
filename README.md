# EatApp

An Android app to keep track of restaurants you've visited — name, cuisine type,
address, rating, price range, notes, visit date, and a photo.

## Features

- List your saved restaurants, searchable by name and filterable by minimum rating
- Add and edit restaurant entries
- View restaurant details, with delete (with confirmation)

## Tech stack

- Kotlin, Jetpack Compose, Material 3
- Navigation Compose for screen navigation
- Room for local persistence
- Kotlin Coroutines

## Project structure

```
app/src/main/java/com/albertferran/eatapp/
├── data/
│   ├── local/        # Room entity, DAO, database, type converters
│   └── repository/   # Repository abstraction over the data source
├── navigation/        # NavHost and route definitions
└── ui/
    ├── list/          # Restaurant list screen + ViewModel
    ├── addedit/        # Add/edit restaurant screen + ViewModel
    ├── detail/         # Restaurant detail screen + ViewModel
    └── theme/          # Compose theming (color, type, shape)
```

## Requirements

- Android Studio (recent stable)
- JDK 17
- Min SDK 26, target/compile SDK 36

## Building

```
./gradlew assembleDebug
```

On Windows use `gradlew.bat assembleDebug`.
