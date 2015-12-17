# Large-Scale Distributed Systems

This repository contains the assignments from the [Large-Scale Distributed Systems lecture](http://mcs.unibnf.ch/program/courses-timetable/courses/large-scale-distributed-systems-3) taught at the [University of Neuchâtel](http://www.unine.ch/) by Dr. Étienne Rivière.

All the assignments are programmed in Lua and use the [Splay framework](http://www.splay-project.org/).

The 3 assignments are as follows:

## Assignment 1: Gossip-based dissemination and Peer-sampling service

- Implementation of the _anti-entropy_ and _rumor mongering_ gossip protocols.
- Implementation of a [peer-sampling service](http://members.unine.ch/etienne.riviere/papers/peer_sampling_tocs.pdf) using both _healer_ and _swapper_ strategies.

## Assignment 2: Distributed Hash Tables (Chord)

Implementation of a Distributed Hash Table using the [Chord](http://members.unine.ch/etienne.riviere/papers/chord.pdf) algorithm.
A first version is only usable with non-failing networks.
The second version is (supposed to be) resilient to faults (a.k.a churn).

## Assignment 3: Chord-on-Demand

Implementation of the [Chord-on-Demand](http://members.unine.ch/etienne.riviere/papers/chordondemand.pdf) algorithm.
The goal is to emerge a Chord DHT structure from chaos by using the T-Man protocol.
The chaos structure is provided through the Peer-sampling service.

