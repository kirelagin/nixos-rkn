import socket
import struct
import sys


def split_cidr(addr):
  sp = addr.split('/')
  if len(sp) == 1: return (addr, 32)
  network, net_bits = sp
  return (network, int(net_bits))

# https://stackoverflow.com/a/33750650/603094
def cidr_to_netmask(network, net_bits):
  host_bits = 32 - net_bits
  netmask = socket.inet_ntoa(struct.pack('!I', (1 << 32) - (1 << host_bits)))
  return (network, netmask)


if __name__ == '__main__':
  for l in sys.stdin:
    for addr in l.strip().split(','):
      (network, net_bits) = split_cidr(addr)
      if net_bits > 31: continue
      print('push "route {} {}"'.format(*cidr_to_netmask(network, net_bits)))
