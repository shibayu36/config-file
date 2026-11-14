#!/usr/bin/ruby
# 指定したノートのSidemarkのsidecar（<ノート>.review.yaml）を監視し、
# 本人がAI宛てに書いた新しいコメントを1件につきJSON 1行で標準出力に書く。
# 該当するコメントを見つけたら BATCH_WINDOW_SEC 待ち、その間に見つけた分とまとめて書く。
#
#   /usr/bin/ruby watch.rb --state <状態ファイル> <ノートの絶対パス>...
#
# 出力:
#   {"event":"comment","note":...,"id":...,"reply_to":...,"text":...}
#   {"event":"error","note":...,"message":...}  sidecarを読めない状態が続いたとき
#
# 状態ファイルには、sidecarごとに既に見たコメントのidを保存する。出力を待っている
# コメントは、出力するまで保存しない。そのため同じ状態ファイルで起動し直すと、
# 止まっていた間に増えたコメントや、出力前に止まったコメントも出力する。
# 状態ファイルに無いsidecarは、その時点のコメントを見たものとして記録するだけで、出力しない。
require "date"
require "fileutils"
require "json"
require "optparse"
require "time"
require "yaml"

AUTHOR = "shibayu36"
MENTION = /(?<![A-Za-z0-9_])@ai(?![A-Za-z0-9_])/
POLL_INTERVAL_SEC = 1
BATCH_WINDOW_SEC = 30
# Sidemarkが書き込んでいる途中のファイルを読んだだけの一時的な失敗では知らせない
FAILURES_BEFORE_ERROR = 3

def emit(event)
  puts JSON.generate(event)
end

def load_comments(note, sidecar)
  raise "note not found" unless File.exist?(note)
  return [] unless File.exist?(sidecar)

  doc = YAML.safe_load(File.read(sidecar, encoding: "UTF-8"), permitted_classes: [Time, Date])
  comments = doc.is_a?(Hash) ? doc["comments"] : nil
  return [] if comments.nil?
  raise "comments is not a list" unless comments.is_a?(Array)

  comments.select { |c| c.is_a?(Hash) && c["id"] }
end

def load_state(path)
  File.exist?(path) ? JSON.parse(File.read(path)) : {}
end

def save_state(path, state)
  FileUtils.mkdir_p(File.dirname(path))
  tmp = "#{path}.tmp"
  File.write(tmp, JSON.generate(state))
  File.rename(tmp, path)
end

state_path = nil
OptionParser.new { |o| o.on("--state PATH") { |v| state_path = v } }.parse!
abort "usage: watch.rb --state <state-file> <note>..." if state_path.nil? || ARGV.empty?

$stdout.sync = true
notes = ARGV.map { |p| File.expand_path(p) }
state = load_state(state_path)
failures = Hash.new(0)
pending = {} # コメントのid => [sidecar, 出力するイベント]
first_pending_at = nil

loop do
  notes.each do |note|
    sidecar = "#{note}.review.yaml"
    begin
      comments = load_comments(note, sidecar)
    rescue StandardError => e
      failures[sidecar] += 1
      emit(event: "error", note: note, message: e.message) if failures[sidecar] == FAILURES_BEFORE_ERROR
      next
    end
    failures.delete(sidecar)

    seen = state[sidecar]
    if seen.nil?
      state[sidecar] = comments.map { |c| c["id"].to_s }
      save_state(state_path, state)
      next
    end

    new_comments = comments.reject { |c| seen.include?(c["id"].to_s) || pending.key?(c["id"].to_s) }
    next if new_comments.empty?

    ignored = []
    new_comments.each do |c|
      id = c["id"].to_s
      if c["author"] == AUTHOR && c["text"].to_s.match?(MENTION)
        pending[id] = [sidecar, { event: "comment", note: note, id: id, reply_to: c["reply_to"], text: c["text"].to_s }]
        first_pending_at ||= Process.clock_gettime(Process::CLOCK_MONOTONIC)
      else
        ignored << id
      end
    end
    unless ignored.empty?
      state[sidecar] = seen + ignored
      save_state(state_path, state)
    end
  end

  if first_pending_at && Process.clock_gettime(Process::CLOCK_MONOTONIC) - first_pending_at >= BATCH_WINDOW_SEC
    pending.each do |id, (sidecar, event)|
      emit(event)
      state[sidecar] << id
    end
    save_state(state_path, state)
    pending.clear
    first_pending_at = nil
  end

  sleep POLL_INTERVAL_SEC
end
