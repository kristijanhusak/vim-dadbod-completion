import { BaseSource, Item } from "https://deno.land/x/ddc_vim@v5.0.1/types.ts";
import {
  GatherArguments,
  GetCompletePositionArguments,
} from "https://deno.land/x/ddc_vim@v5.0.1/base/source.ts";

type Params = Record<never, never>;

export class Source extends BaseSource<Params> {
  override async gather(
    args: GatherArguments<Params>,
  ): Promise<Item[]> {
    const items = await args.denops.call(
      "vim_dadbod_completion#omni",
      0,
      args.completeStr,
    ) as Item[];
    return items;
  }
  override async getCompletePosition(
    args: GetCompletePositionArguments<Params>,
  ): Promise<number> {
    const pos = await args.denops.call(
      "vim_dadbod_completion#omni",
      1,
      "",
    ) as number;
    return pos;
  }
  override params(): Params {
    return {};
  }
}

