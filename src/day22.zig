usingnamespace @import("util.zig");

pub fn runPart1(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    return parseAndPlay(r, &arena.allocator);
}

pub fn runPart2(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var d1 = try parseDeck(r, &arena.allocator);
    var d2 = try parseDeck(r, &arena.allocator);

    var first_wins: bool = undefined;
    return playRecursive(&d1, &d2, true, &first_wins, &arena.allocator);
}

const Deck = TailQueue(usize);
const DeckHash = u32;

// Returns true if the first player wins.
pub fn playRecursive(d1: *Deck, d2: *Deck, need_score: bool, first_wins: *bool, a: *Allocator) anyerror!usize {
    var rounds = AutoHashMap(DeckHash, bool).init(a);
    defer rounds.deinit();

    var round_no: usize = 0;
    while (true) {
        assert(round_no == rounds.count());
        round_no += 1;
        const h = try hashDecks(d1.*, d2.*, a);
        if (rounds.get(h) != null) {
            first_wins.* = true;
            return if (need_score) calcPoints(d1.*) else 0;
        }
        try rounds.put(h, true);

        var e1 = d1.popFirst().?;
        var e2 = d2.popFirst().?; 
        first_wins.* = e1.data > e2.data;
        if (d1.len >= e1.data and d2.len >= e2.data) {
            var new_d1 = try copyDeck(d1.*, e1.data, a);
            var new_d2 = try copyDeck(d2.*, e2.data, a);
            _ = try playRecursive(&new_d1, &new_d2, false, first_wins, a);
        }

        if (first_wins.*) {
            d1.append(e1);
            d1.append(e2);
            if (d2.len == 0)
                return if (need_score) calcPoints(d1.*) else 0;
        } else {
            d2.append(e2);
            d2.append(e1);
            if (d1.len == 0)
                return if (need_score) calcPoints(d2.*) else 0;
        }
    }
}

fn hashDecks(d1: Deck, d2: Deck, a: *Allocator) !DeckHash {
    comptime const sz = @typeInfo(usize).Int.bits / 8;
    var curr = d1.first;
    var buf = try a.alloc(u8, sz * (d1.len + d2.len + 2));
    defer a.free(buf);
    mem.set(u8, buf, 0);

    var b = buf;
    mem.writeIntBig(usize, b[0..sz], d1.len);
    b = b[sz..];
    while (curr != null) {
        mem.writeIntBig(usize, b[0..sz], curr.?.data);
        b = b[sz..];
        curr = curr.?.next;
    }

    mem.writeIntBig(usize, b[0..sz], d2.len);
    b = b[sz..];
    curr = d2.first;
    while (curr != null) {
        mem.writeIntBig(usize, b[0..sz], curr.?.data);
        b = b[sz..];
        curr = curr.?.next;
    }

    return hash.Fnv1a_32.hash(buf);
}

fn copyDeck(d: Deck, n: usize, a: *Allocator) !Deck {
    var cd: Deck = Deck{};
    var curr = d.first;
    var i: usize = 0;
    while (i < n) {
        const node = try a.create(Deck.Node);
        node.data = curr.?.data;
        cd.append(node);
        curr = curr.?.next;
        i += 1;
    }
    return cd;
}

fn printDeck(d: Deck) void {
    var curr = d.first;
    print("deck: ", .{});
    while (curr != null) {
        print("{} ", .{ curr.?.data });
        curr = curr.?.next;
    }
    print("\n", .{});
}

fn parseAndPlay(r: anytype, a: *Allocator) !usize {
    var d1 = try parseDeck(r, a);
    var d2 = try parseDeck(r, a);

    var e1 = d1.popFirst();
    var e2 = d2.popFirst();
    while (e1 != null and e2 != null) {
        const num1 = e1.?.data;
        const num2 = e2.?.data;
        if (num1 > num2) {
            d1.append(e1.?);
            d1.append(e2.?);
        } else {
            d2.append(e2.?);
            d2.append(e1.?);
        }
        e1 = d1.popFirst();
        e2 = d2.popFirst();
    }
    if (e1 == null) {
        assert(e2 != null);
        d2.prepend(e2.?);
        return calcPoints(d2);
    }
    if (e2 == null) {
        assert(e1 != null);
        d1.prepend(e1.?);
        return calcPoints(d1);
    }
    unreachable;
}

fn calcPoints(d: Deck) usize {
    var curr = d.last;
    var mult: usize = 1;
    var score: usize = 0;
    while (curr != null) {
        score += curr.?.data * mult;
        mult += 1;
        curr = curr.?.prev;
    }
    return score;
}

fn parseDeck(r: anytype, a: *Allocator) !Deck {
    var deck = Deck{};
    var buf: [20]u8 = undefined;
    var line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse return error.InvalidInput;
    while (true) {
        line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse break;
        if (line.len == 0)
            break;
        const num = try fmt.parseUnsigned(usize, line, 10);
        const node = try a.create(Deck.Node);
        node.data = num;
        deck.append(node);
    }
    return deck;
}

test "part 1" {
    const input =
        \\Player 1:
        \\9
        \\2
        \\6
        \\3
        \\1
        \\
        \\Player 2:
        \\5
        \\8
        \\4
        \\7
        \\10
        ;
    var r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 306), try runPart1(r));

    r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 291), try runPart2(r));
}

test "part2, finite" {
    const input =
        \\Player 1:
        \\43
        \\19
        \\
        \\Player 2:
        \\2
        \\29
        \\14
        ;
    var r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 105), try runPart2(r));    
}