import serial
import sys
import numpy as np
from typing import List
from time import sleep
from random import seed
from random import randint
import argparse

class RGBSerialInfoClient():
   def __init__(self, serialPort='/dev/ttyUSB1', baudRate=1500000, timeout = 100e-3):
      self.ser = serial.Serial(serialPort, baudRate, timeout = timeout)
      self.writeOutput = False

   def setDebugTransfers(self, writeOutput : bool):
      self.writeOutput = writeOutput

   def convertToHexWord(self, dataWord : int, size=6):
      wordStr = hex(dataWord)[2:]
      if len(wordStr) < size:
         wordStr = '0'*(size-len(wordStr)) + wordStr
      return wordStr

   def convertFromHexWord(self, hexWord : str):
      return int(hexWord, 16)

   def measure(self):
      dataToSend = bytes('M', 'ascii');
      self.ser.write(dataToSend)
      self.ser.flush()
      line=self.ser.readline()
      if self.writeOutput:
         print(line)
      if line[0:3] != b'ACK':
         raise Exception('Failed to execute Measure command')

   def read(self) -> {}:
      dataToSend = bytes('R', 'ascii');
      self.ser.write(dataToSend)
      self.ser.flush()
      if self.writeOutput:
         print(dataToSend, end='')
      lineData=self.ser.readline()
      if self.writeOutput:
         print(lineData, end='')
      if lineData[0:3] == b'NAK':
         raise Exception('Failed to execute Read command - ACK not received')         
      line=self.ser.readline()
      if self.writeOutput:
         print(line)   
      if line[0:3] != b'ACK':
         raise Exception('Failed to execute Read command - ACK not received')
      data = {}
      dataWords = lineData.split(b',')
      if len(dataWords) != 17:
         raise Exception('Failed to execute Read command - Expected ' + str(17) + ' words, but received ' + str(len(dataWords)))    
         
      data['hasDE'] = self.convertFromHexWord(dataWords[0])
      data['frameCycles'] = self.convertFromHexWord(dataWords[1])
      data['HScycles'] = self.convertFromHexWord(dataWords[2])
      data['VScycles'] = self.convertFromHexWord(dataWords[3])
      data['DElines'] = self.convertFromHexWord(dataWords[4])
      data['ImgLines'] = self.convertFromHexWord(dataWords[5])
      data['FrameLines'] = self.convertFromHexWord(dataWords[6])
      data['ColumnPixels'] = self.convertFromHexWord(dataWords[7])
      data['BPHCycles'] = self.convertFromHexWord(dataWords[8])
      data['BPVLines'] = self.convertFromHexWord(dataWords[9])
      data['FPHCycles'] = self.convertFromHexWord(dataWords[10])
      data['FPVLines'] = self.convertFromHexWord(dataWords[11])
      data['VgaFPVLines'] = self.convertFromHexWord(dataWords[12])
      data['VgaBPVLines'] = self.convertFromHexWord(dataWords[13])
      data['VgaBPHEndCycle'] = self.convertFromHexWord(dataWords[14])
      data['VgaFPHStartCycle'] = self.convertFromHexWord(dataWords[15])
      data['VgaFPHEndCycle'] = self.convertFromHexWord(dataWords[16])
      
      return data
      
   def interpretParameters(self, parameters, clockFrequency=None):
      hasDE = parameters['hasDE']
      if hasDE == 1:
         print('Print pixel DataEnable signal was available')
      else:
         print('Print pixel DataEnable signal was NOT available')
         
      print('Frame time: ' + str(parameters['frameCycles']) + ' pixel clock cycles', end='')
      if not clockFrequency is None:
         frameTime = parameters['frameCycles'] / clockFrequency
         fps = 1.0/frameTime
         print(', or {:.3f} s per frame, or {:.3f} fps.'.format(frameTime, fps))
      else:
         print('.')
         
      print('Horizontal sync: {:d} pixel clock cycles'.format(parameters['HScycles']), end='')
      if not clockFrequency is None:
         hsTime=parameters['HScycles'] / clockFrequency
         print(', or {:.9f}s'.format(hsTime));
      else:
         print('.')
      
      print('Vertical sync: {:d} pixel clock cycles'.format(parameters['VScycles']), end='')
      if not clockFrequency is None:
         vsTime=parameters['VScycles'] / clockFrequency
         print(', or {:.9f}s'.format(vsTime));
      else:
         print('.')
         
      if hasDE == 1:
         print('Image pixels per line with pixel DataEnable signal active: {:d} scanlines'.format(parameters['DElines']))
      
         print('Image pixel lines: {:d} scanlines'.format(parameters['ImgLines']))
      print('Total frame lines: {:d} scanlines'.format(parameters['FrameLines']))   
      print('Total scanline length without horizontal sync.: {:d} video clock cycles'.format(parameters['ColumnPixels']))
      
      if hasDE == 1:
         print('Horizontal Back Porch: {:d} video clock cycles'.format(parameters['BPHCycles']), end='')
         if not clockFrequency is None:
            bphTime=parameters['BPHCycles'] / clockFrequency
            print(', or {:.9f}s'.format(bphTime));
         else:
            print('.')

         print('Horizontal Front Porch: {:d} video clock cycles'.format(parameters['FPHCycles']), end='')
         if not clockFrequency is None:
            fphTime=parameters['FPHCycles'] / clockFrequency
            print(', or {:.9f}s'.format(fphTime));
         else:
            print('.')

         print('Vertical Front Porch: {:d} scanlines'.format(parameters['FPVLines']), end='')
         if not clockFrequency is None:
            fpvTime=parameters['FPVLines'] * parameters['ColumnPixels'] / clockFrequency
            print(', or {:.9f}s'.format(fpvTime));
         else:
            print('.')

         print('Vertical Back Porch: {:d} scanlines'.format(parameters['BPVLines']), end='')
         if not clockFrequency is None:
            bpvTime=parameters['BPVLines'] * parameters['ColumnPixels'] / clockFrequency
            print(', or {:.9f}s'.format(bpvTime));
         else:
            print('.')

      print('--------------------------------')
      print('--- VGA estimated parameters ---')
      print('--------------------------------')
      print('Horizontal Front Porch start cycle: {:d} start pixel clock cycle.'.format(parameters['VgaFPHStartCycle']))
      print('Horizontal Front Porch end cycle: {:d} end pixel clock cycle.'.format(parameters['VgaFPHEndCycle']))
            
      print('Horizontal Back Porch: {:d} video clock cycles/pixels'.format(parameters['VgaBPHEndCycle']), end='')
      if not clockFrequency is None:
         bphTime=parameters['VgaBPHEndCycle'] / clockFrequency
         print(', or {:.9f}s'.format(bphTime));
      else:
         print('.')
      
      print('Total scanline length without horizontal sync.: {:d} video clock cycles.'.format(parameters['VgaFPHEndCycle']))
      fphCycles = parameters['VgaFPHEndCycle'] - parameters['VgaFPHStartCycle'];
      print('Computed Horizontal Front Porch: {:d} pixel clock cycles/pixels'.format(fphCycles), end='')
      if not clockFrequency is None:
         fphTime=fphCycles / clockFrequency
         print(', or {:.9f}s'.format(fphTime));
      else:
         print('.')
      
      print('Vertical Front Porch: {:d} scanlines'.format(parameters['VgaFPVLines']), end='')
      if not clockFrequency is None:
         fpvTime=parameters['VgaFPVLines'] * parameters['ColumnPixels'] / clockFrequency
         print(', or {:.9f}s'.format(fpvTime));
      else:
         print('.')

      print('Vertical Back Porch: {:d} scanlines'.format(parameters['VgaBPVLines']), end='')
      if not clockFrequency is None:
         bpvTime=parameters['VgaBPVLines'] * parameters['ColumnPixels'] / clockFrequency
         print(', or {:.9f}s'.format(bpvTime));
      else:
         print('.')

      print('------------------------')
      print('--- Other statistics ---')
      print('------------------------')
      
      lineWidthCycles = float(parameters['HScycles'] + parameters['ColumnPixels'])
      vsLines = parameters['VScycles'] / lineWidthCycles
      print('Vertical sync: {:.3f} lines.'.format(vsLines))
      frameLines = parameters['frameCycles'] / lineWidthCycles
      print('Frame: {:.3f} total scanlines.'.format(frameLines))
      

      print('Ok')  

def measure():
   client = RGBSerialInfoClient(serialPort='/dev/ttyUSB1')
   client.setDebugTransfers(True)
   client.measure()
   
def read(clkFrequency = None):
   client = RGBSerialInfoClient(serialPort='/dev/ttyUSB1')
   client.setDebugTransfers(True)
   videoParameters = client.read()
   client.interpretParameters(videoParameters, clkFrequency)
  
def measureAndRead(clkFrequency = None):
   client = RGBSerialInfoClient(serialPort='/dev/ttyUSB1')
   client.setDebugTransfers(True)
   print('Test passed!')

if __name__ == "__main__":
   parser = argparse.ArgumentParser()
   op_arg = parser.add_argument('--op', dest='op', help='Select the type of test to run: measure, read, measureAndRead')
   vidclk_arg = parser.add_argument('--vidclk', dest='vidclk', help='The Video clock frequency in Hz')

   args = parser.parse_args()
   clockFrequency = None
   if not args.vidclk is None:
      clockFrequency = float(args.vidclk)
   
   if args.op == 'measure':
      measure()
   if args.op == 'read':
      read(clockFrequency)
   if args.op == 'measureAndRead':
      measureAndRead(clockFrequency)
