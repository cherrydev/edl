require File.dirname(__FILE__) + '/../edl'
require 'rubygems'
require 'test/unit'
require 'flexmock'
require 'flexmock/test_unit'


class TestEvent < Test::Unit::TestCase
  def test_attributes_defined
    evt = EDL::Event.new
    %w(  num reel track src_start_tc src_end_tc rec_start_tc rec_end_tc ).each do | em |
      assert_respond_to evt, em
    end
  end
end

class TestParser < Test::Unit::TestCase
  def test_inst
    assert_nothing_raised { EDL::Parser.new }
  end
  
  TRAILER_EDL = File.dirname(__FILE__) + '/samples/TRAILER_EDL.edl'
  SIMPLE_DISSOLVE = File.dirname(__FILE__) + '/samples/SIMPLE_DISSOLVE.edl'
  SPLICEME = File.dirname(__FILE__) + '/samples/SPLICEME.edl'
  
  def test_timecode_from_elements
    elems = ["08", "04", "24", "24"]
    assert_nothing_raised { @tc = EDL::Parser.timecode_from_line_elements(elems) }
    assert_kind_of Timecode, @tc
    assert_equal "08:04:24:24", @tc.to_s
    assert elems.empty?, "The elements should have been removed from the array"
  end
  
  def test_dissolve
    p = EDL::Parser.new
    assert_nothing_raised{ @edl = p.parse File.open(SIMPLE_DISSOLVE) }
    assert_kind_of EDL::List, @edl
    assert_equal 2, @edl.events.length
    
    first = @edl.events[0]
    assert_kind_of EDL::Clip, first
    
    second = @edl.events[1]
    assert_kind_of EDL::Transition, second
    
    no_trans = @edl.without_dissolves
    
    assert_equal 2, no_trans.events.length
    assert_equal (Timecode.parse('01:00:00:00') + 43).to_s, no_trans.events[0].rec_end_tc.to_s, 
      "The incoming clip should have been extended by the length of the dissolve"
      
    assert_equal Timecode.parse('01:00:00:00').to_s, no_trans.events[1].rec_start_tc.to_s
      "The outgoing clip should have been left in place"
  end
  
  def test_spliced
    p = EDL::Parser.new
    assert_nothing_raised{ @edl = p.parse(File.open(SPLICEME)) }
    assert_equal 3, @edl.events.length
    
    spliced = @edl.spliced
    assert_equal 1, spliced.events.length, "Should have been spliced to one event"
  end
end

class TimewarpMatcherTest < Test::Unit::TestCase
  def test_needs_to_be_written
    flunk
  end
end

class EventMatcherTest < Test::Unit::TestCase

  EVT_PATTERNS = [
    '020  008C     V     C        08:04:24:24 08:04:25:19 01:00:25:22 01:00:26:17', 
    '021  009      V     C        00:39:04:21 00:39:05:09 01:00:26:17 01:00:27:05', 
    '022  008C     V     C        08:08:01:23 08:08:02:18 01:00:27:05 01:00:28:00', 
    '023  008C     V     C        08:07:30:02 08:07:30:21 01:00:28:00 01:00:28:19', 
    '024        AX V     C        00:00:00:00 00:00:01:00 01:00:28:19 01:00:29:19', 
    '025        BL V     C        00:00:00:00 00:00:00:00 01:00:29:19 01:00:29:19', 
    '025  GEN      V     D    025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20',
  ]

  def test_clip_generation_from_line
    m = EDL::EventMatcher.new
    
    clip = m.apply(nil, nil,
      '020  008C     V     C        08:04:24:24 08:04:25:19 01:00:25:22 01:00:26:17'
    )
    
    assert_not_nil clip
    assert_kind_of EDL::Clip, clip
    assert_equal '020', clip.num
    assert_equal '008C', clip.reel
    assert_equal 'V', clip.track
    assert_equal '08:04:24:24', clip.src_start_tc.to_s
    assert_equal '08:04:25:19', clip.src_end_tc.to_s
    assert_equal '01:00:25:22', clip.rec_start_tc.to_s
    assert_equal '01:00:26:17', clip.rec_end_tc.to_s
    assert_equal '020  008C     V     C        08:04:24:24 08:04:25:19 01:00:25:22 01:00:26:17', clip.original_line
  end
  
  def test_dissolve_generation_from_line
    m = EDL::EventMatcher.new
    dissolve = m.apply(nil, nil,
      '025  GEN      V     D    025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20'
    )
    assert_not_nil dissolve
    assert_kind_of EDL::Transition, dissolve
    assert_equal '025', dissolve.num
    assert_equal 'GEN', dissolve.reel
    assert_equal 'V', dissolve.track
    assert_equal '025', dissolve.duration
    assert_equal '025  GEN      V     D    025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20', dissolve.original_line
  end
  
  def test_black_generation_from_line
    m = EDL::EventMatcher.new
    black = m.apply(nil, nil,
      '025        BL V     C        00:00:00:00 00:00:00:00 01:00:29:19 01:00:29:19' 
    )
    assert_not_nil black
    assert_kind_of EDL::Black, black
    assert_equal '025', black.num
    assert_equal 'BL', black.reel
    assert_equal 'V', black.track
    assert_equal '025        BL V     C        00:00:00:00 00:00:00:00 01:00:29:19 01:00:29:19', black.original_line
  end
  
  def test_matches_all_patterns
    EVT_PATTERNS.each do | pat |
      assert EDL::EventMatcher.new.matches?(pat), "EventMatcher should match #{pat}"
    end
  end
end

class ClipNameMatcherTest < Test::Unit::TestCase
  def test_matches
    line = "* FROM CLIP NAME:  TAPE_6-10.MOV"
    assert EDL::NameMatcher.new.matches?(line)
  end
  
  def test_apply
    line = "* FROM CLIP NAME:  TAPE_6-10.MOV"
    mok_evt = flexmock
    mok_evt.should_receive(:clip_name=).with('TAPE_6-10.MOV').once
    EDL::NameMatcher.new.apply([], mok_evt, line)
  end
end

class EffectMatcherTest < Test::Unit::TestCase
  def test_matches
    line = "* EFFECT NAME: CROSS DISSOLVE"
    assert EDL::EffectMatcher.new.matches?(line)
  end
  
  def test_apply
    line = "* EFFECT NAME: CROSS DISSOLVE"
    mok_evt = flexmock
    mok_evt.should_receive(:effect=).with('CROSS DISSOLVE').once
    EDL::EffectMatcher.new.apply([], mok_evt, line)
  end
end