# AprsUtils 

Library with two useful (hopefully) modules for APRS developers.
* `AprsParser`: Module for parsing APRS packets into components.
* `AprsIs`: Module for connecting to APRS-IS

## Short explanation

APRS stands for "Automatic Position Reporting System". It is a protocol used by
amateur radio operators around the world to track the location of moving objects 
via packet radio. If you want to take a look at what is being tracked right now
in your area, visit [here](https://aprs.fi).

## References

If you want to learn more you can start with the specifications below. Recieving
all of this data is free and open to anyone. However, you need to be a licensed
ham to inject any data into the network, even into the internet servers, because
that data can be broadcast over ham radio frequencies.

### The APRS Spec
* [APRS 1.0.1 Spec](http://www.aprs.org/doc/APRS101.PDF)
* [APRS 1.1 Addendum](http://www.aprs.org/aprs11.html)
* [APRS 1.2 Addendum](http://www.aprs.org/aprs12.html)

### The APRS_IS documentation
* [APRS-IS](https://www.aprs-is.net/)

## Installation

Add `aprs_utils` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:aprs_utils, "~> 0.1.0"}
  ]
end
```


