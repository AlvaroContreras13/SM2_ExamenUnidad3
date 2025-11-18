import 'package:flutter_test/flutter_test.dart';
import 'package:movuni/constants/trip_status.dart';
import 'package:movuni/utils/address_resolver.dart';
import 'package:movuni/services/rating_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  // TESTS para TripStatus (constants/trip_status.dart)
  group('TripStatus Tests', () {
    test('isValid debe retornar true para estados válidos', () {
      expect(TripStatus.isValid('activo'), true);
      expect(TripStatus.isValid('en_curso'), true);
      expect(TripStatus.isValid('completado'), true);
      expect(TripStatus.isValid('cancelado'), true);
    });

    test('isValid debe retornar false para estados inválidos', () {
      expect(TripStatus.isValid('invalido'), false);
      expect(TripStatus.isValid(''), false);
      expect(TripStatus.isValid('ACTIVO'), false);
      expect(TripStatus.isValid('pendiente'), false);
    });

    test('getDisplayText debe retornar el texto correcto para cada estado', () {
      expect(TripStatus.getDisplayText('activo'), 'Activo');
      expect(TripStatus.getDisplayText('en_curso'), 'En Curso');
      expect(TripStatus.getDisplayText('completado'), 'Completado');
      expect(TripStatus.getDisplayText('cancelado'), 'Cancelado');
      expect(TripStatus.getDisplayText('invalido'), 'Desconocido');
    });

    test('getColorHex debe retornar colores válidos en formato hexadecimal', () {
      expect(TripStatus.getColorHex('activo'), '#4CAF50');
      expect(TripStatus.getColorHex('en_curso'), '#2196F3');
      expect(TripStatus.getColorHex('completado'), '#9E9E9E');
      expect(TripStatus.getColorHex('cancelado'), '#F44336');
      expect(TripStatus.getColorHex('invalido'), '#9E9E9E');
    });

    test('allStatus debe contener exactamente 4 estados', () {
      expect(TripStatus.allStatus.length, 4);
      expect(TripStatus.allStatus, contains('activo'));
      expect(TripStatus.allStatus, contains('en_curso'));
      expect(TripStatus.allStatus, contains('completado'));
      expect(TripStatus.allStatus, contains('cancelado'));
    });
  });

  // TESTS para AddressResolver (utils/address_resolver.dart)
  group('AddressResolver Tests', () {
    test('resolveAddressFromData debe retornar defaultName cuando location es null', () async {
      final result = await resolveAddressFromData(null, 'Ubicación Desconocida');
      expect(result, 'Ubicación Desconocida');
    });

    test('resolveAddressFromData debe retornar el nombre si ya existe y no es coordenada', () async {
      final location = {
        'nombre': 'Universidad Nacional',
        'lat': -12.0464,
        'lng': -77.0428,
      };
      final result = await resolveAddressFromData(location, 'Default');
      expect(result, 'Universidad Nacional');
    });

    test('resolveAddressFromData debe retornar coordenadas formateadas cuando no hay nombre válido', () async {
      final location = {
        'nombre': '',
        'lat': -12.0464,
        'lng': -77.0428,
      };
      final result = await resolveAddressFromData(location, 'Default');
      // Debe contener formato de coordenadas
      expect(result, contains('Lat:'));
      expect(result, contains('Lng:'));
      expect(result, contains('-12.046'));
      expect(result, contains('-77.042'));
    });

    test('resolveAddressFromData debe retornar defaultName cuando no hay coordenadas válidas', () async {
      final location = {
        'nombre': '',
        'lat': null,
        'lng': null,
      };
      final result = await resolveAddressFromData(location, 'Sin Ubicación');
      expect(result, 'Sin Ubicación');
    });

    test('resolveAddressFromData debe manejar coordenadas como int o double', () async {
      final location = {
        'nombre': '',
        'lat': -12,  
        'lng': -77.5,
      };
      final result = await resolveAddressFromData(location, 'Default');
      expect(result, contains('Lat:'));
      expect(result, contains('Lng:'));
    });
  });

  
  // TESTS para RatingService (services/rating_service.dart)
  group('RatingService Tests', () {
    late RatingService ratingService;
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      ratingService = RatingService(firestore: fakeFirestore);
    });

    test('createRating debe lanzar excepción si rating está fuera del rango 1-5', () async {
      expect(
        () => ratingService.createRating(
          tripId: 'trip123',
          ratedUserId: 'user1',
          raterUserId: 'user2',
          rating: 0,
        ),
        throwsException,
      );

      expect(
        () => ratingService.createRating(
          tripId: 'trip123',
          ratedUserId: 'user1',
          raterUserId: 'user2',
          rating: 6,
        ),
        throwsException,
      );
    });

    test('createRating debe lanzar excepción si el usuario intenta calificarse a sí mismo', () async {
      expect(
        () => ratingService.createRating(
          tripId: 'trip123',
          ratedUserId: 'user1',
          raterUserId: 'user1',
          rating: 5,
        ),
        throwsException,
      );
    });

    test('createRating debe crear una calificación válida correctamente', () async {
      // Crear el usuario primero para que _updateUserRating funcione
      await fakeFirestore.collection('users').doc('user1').set({
        'firstName': 'Juan',
        'lastName': 'Pérez',
        'rating': 5.0,
        'totalRatings': 0,
      });

      await ratingService.createRating(
        tripId: 'trip123',
        ratedUserId: 'user1',
        raterUserId: 'user2',
        rating: 4.5,
        comment: 'Excelente conductor',
      );

      final ratings = await fakeFirestore.collection('ratings').get();
      expect(ratings.docs.length, 1);
      expect(ratings.docs.first.data()['rating'], 4.5);
      expect(ratings.docs.first.data()['comment'], 'Excelente conductor');
      expect(ratings.docs.first.data()['tripId'], 'trip123');
    });

    test('getUserAverageRating debe retornar 5.0 cuando el usuario no existe', () async {
      final rating = await ratingService.getUserAverageRating('userInexistente');
      expect(rating, 5.0);
    });

    test('getUserAverageRating debe retornar el rating del usuario si existe', () async {
      await fakeFirestore.collection('users').doc('user1').set({
        'firstName': 'Juan',
        'lastName': 'Pérez',
        'rating': 4.7,
        'totalRatings': 10,
      });

      final rating = await ratingService.getUserAverageRating('user1');
      expect(rating, 4.7);
    });

    test('getUserTotalRatings debe retornar 0 cuando el usuario no tiene calificaciones', () async {
      final total = await ratingService.getUserTotalRatings('userInexistente');
      expect(total, 0);
    });

    test('getUserTotalRatings debe retornar el total correcto de calificaciones', () async {
      await fakeFirestore.collection('users').doc('user1').set({
        'firstName': 'Juan',
        'lastName': 'Pérez',
        'rating': 4.5,
        'totalRatings': 25,
      });

      final total = await ratingService.getUserTotalRatings('user1');
      expect(total, 25);
    });

    test('canRateUser debe retornar true cuando no existe calificación previa', () async {
      final canRate = await ratingService.canRateUser(
        tripId: 'trip123',
        raterUserId: 'user1',
        ratedUserId: 'user2',
      );
      expect(canRate, true);
    });

    test('canRateUser debe retornar false cuando ya existe una calificación', () async {
      await fakeFirestore.collection('ratings').add({
        'tripId': 'trip123',
        'raterUserId': 'user1',
        'ratedUserId': 'user2',
        'rating': 5.0,
        'comment': 'Muy bien',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final canRate = await ratingService.canRateUser(
        tripId: 'trip123',
        raterUserId: 'user1',
        ratedUserId: 'user2',
      );
      expect(canRate, false);
    });
  });
}
