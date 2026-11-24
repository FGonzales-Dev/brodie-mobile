import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/core_providers.dart';
import '../domain/group_ride_models.dart';
import '../domain/position_codec.dart';

part 'trip_channel.g.dart';

/// Something that arrived on a trip's live channel.
sealed class TripChannelEvent {
  const TripChannelEvent();
}

class RiderFixReceived extends TripChannelEvent {
  const RiderFixReceived(this.fix);

  final RiderFix fix;
}

/// The seats whose phones are connected to the channel right now.
class OnlineSeatsChanged extends TripChannelEvent {
  const OnlineSeatsChanged(this.seats);

  final Set<int> seats;
}

/// A rider turned their SOS on or off.
class RiderSosChanged extends TripChannelEvent {
  const RiderSosChanged(this.signal);

  final SosSignal signal;
}

/// The leader rerouted the group; the new route is version [version].
class TripRouteChanged extends TripChannelEvent {
  const TripRouteChanged(this.version);

  final int version;
}

/// The leader ended the ride.
class TripEndedByLeader extends TripChannelEvent {
  const TripEndedByLeader();
}

/// Whether the channel is connected; sends still go out over REST when not.
class ChannelConnectionChanged extends TripChannelEvent {
  const ChannelConnectionChanged({required this.connected});

  final bool connected;
}

/// A trip's live channel: riders' positions (broadcast) and who's online
/// (presence). Nothing sent here is stored; the server only checks that the
/// sender joined the trip (see `can_use_trip_channel` in brodie-supabase).
abstract interface class TripChannel {
  Stream<TripChannelEvent> get events;

  /// Joins the channel and shows this rider online as [seat].
  Future<void> connect({required int seat});

  /// Over the open connection, or REST when there isn't one (e.g. the app
  /// is in the background) or [viaRest] is set.
  Future<void> sendFix(RiderFix fix, {bool viaRest = false});

  /// Tells everyone the leader ended the ride.
  Future<void> announceEnd();

  /// Tells everyone the leader saved a new route, [version], so they fetch it
  /// now rather than at their next trip check. Over REST, like [announceEnd].
  Future<void> announceRoute(int version);

  /// Tells everyone this rider needs help, or is safe again. Always over
  /// REST too, so it goes out even when the connection is down.
  Future<void> sendSos(SosSignal signal);

  Future<void> close();
}

class SupabaseTripChannel implements TripChannel {
  SupabaseTripChannel(this._client, this.tripId);

  static const _fixEvent = 'pos';
  static const _endEvent = 'end';
  static const _sosEvent = 'sos';
  static const _routeEvent = 'route';

  final SupabaseClient _client;
  final String tripId;
  final _events = StreamController<TripChannelEvent>.broadcast();
  RealtimeChannel? _channel;

  /// Subscribed over the open connection; sends use REST while not.
  var _connected = false;

  @override
  Stream<TripChannelEvent> get events => _events.stream;

  @override
  Future<void> connect({required int seat}) {
    final joined = Completer<void>();
    // The presence key is the seat, so presence tells us who is online
    // without sending user ids around.
    final channel = _client.channel('trip:$tripId', opts: RealtimeChannelConfig(private: true, key: '$seat'));
    _channel = channel;
    channel
        .onBroadcast(event: _fixEvent, callback: _onFix)
        .onBroadcast(event: _endEvent, callback: (_) => _emit(const TripEndedByLeader()))
        .onBroadcast(event: _sosEvent, callback: _onSos)
        .onBroadcast(event: _routeEvent, callback: _onRoute)
        .onPresenceSync((_) => _emit(OnlineSeatsChanged(_onlineSeats(channel))))
        .subscribe((status, error) async {
          switch (status) {
            case RealtimeSubscribeStatus.subscribed:
              _setConnected(true);
              await channel.track({'seat': seat});
              if (!joined.isCompleted) joined.complete();
            case RealtimeSubscribeStatus.channelError || RealtimeSubscribeStatus.timedOut:
              _setConnected(false);
              // The client keeps retrying; only the first failure is reported.
              if (!joined.isCompleted) {
                joined.completeError(error ?? TimeoutException('Could not join the ride channel'));
              }
            case RealtimeSubscribeStatus.closed:
              _setConnected(false);
          }
        });
    return joined.future;
  }

  void _onFix(Map<String, dynamic> message) {
    final payload = message['payload'];
    if (payload is! Map) return;
    final fix = PositionCodec.decode(Map<String, dynamic>.from(payload));
    if (fix != null) _emit(RiderFixReceived(fix));
  }

  void _onRoute(Map<String, dynamic> message) {
    final payload = message['payload'];
    if (payload is Map && payload['v'] is int) _emit(TripRouteChanged(payload['v'] as int));
  }

  void _onSos(Map<String, dynamic> message) {
    final payload = message['payload'];
    if (payload is! Map) return;
    final signal = PositionCodec.decodeSos(Map<String, dynamic>.from(payload));
    if (signal != null) _emit(RiderSosChanged(signal));
  }

  static Set<int> _onlineSeats(RealtimeChannel channel) => {
    for (final state in channel.presenceState())
      if (int.tryParse(state.key) case final int seat) seat,
  };

  @override
  Future<void> sendFix(RiderFix fix, {bool viaRest = false}) async {
    final channel = _channel;
    if (channel == null) return;
    final payload = PositionCodec.encode(fix);
    if (!viaRest && _connected) {
      await channel.sendBroadcastMessage(event: _fixEvent, payload: payload);
    } else {
      await channel.httpSend(event: _fixEvent, payload: payload);
    }
  }

  @override
  Future<void> announceEnd() async {
    final channel = _channel;
    if (channel == null) return;
    // REST, so it goes out even if the connection just dropped.
    await channel.httpSend(event: _endEvent, payload: const <String, dynamic>{});
  }

  @override
  Future<void> announceRoute(int version) async {
    final channel = _channel;
    if (channel == null) return;
    await channel.httpSend(event: _routeEvent, payload: {'v': version});
  }

  @override
  Future<void> sendSos(SosSignal signal) async {
    final channel = _channel;
    if (channel == null) return;
    await channel.httpSend(event: _sosEvent, payload: PositionCodec.encodeSos(signal));
  }

  @override
  Future<void> close() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        // Drops this rider from everyone's online list straight away.
        await channel.untrack();
      } catch (_) {}
      await _client.removeChannel(channel);
    }
    await _events.close();
  }

  void _setConnected(bool connected) {
    _connected = connected;
    _emit(ChannelConnectionChanged(connected: connected));
  }

  void _emit(TripChannelEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}

/// Opens a trip's channel; tests replace it with a fake.
typedef TripChannelFactory = TripChannel Function(String tripId);

@riverpod
TripChannelFactory tripChannelFactory(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return (tripId) => SupabaseTripChannel(client, tripId);
}
