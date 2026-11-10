import gleam/list
import roost_codec_bench/fixture
import unitest

pub fn main() {
  unitest.main()
}

pub fn text_fixtures_test() {
  [128, 4096, 65_536]
  |> list.flat_map(fixture.text)
  |> fixture.check
}

pub fn binary_fixtures_test() {
  [128, 4096, 65_536]
  |> list.flat_map(fixture.binary)
  |> fixture.check
}

pub fn rejections_test() {
  fixture.check_rejections()
}

pub fn boundaries_test() {
  fixture.check_boundaries()
}
