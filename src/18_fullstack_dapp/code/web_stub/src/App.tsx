import { useCurrentAccount, useCurrentClient } from '@mysten/dapp-kit-react';
import { ConnectButton } from '@mysten/dapp-kit-react/ui';
import { useQuery } from '@tanstack/react-query';

export default function App() {
  const account = useCurrentAccount();
  const client = useCurrentClient();
  const chainProbe = useQuery({
    queryKey: ['chainIdentifier'],
    queryFn: () => client.core.getChainIdentifier(),
    retry: false,
  });

  return (
    <main style={{ fontFamily: 'system-ui', padding: '1.5rem' }}>
      <h1>第十八章 · 前端骨架（dApp Kit + gRPC）</h1>
      <p>
        本目录为全栈章最小可运行示例：<code>@mysten/dapp-kit-react</code>、
        <code>@tanstack/react-query</code> 与 gRPC 客户端（见 <code>src/dapp-kit.ts</code>
        ）。链上查询请用 <code>useQuery</code> + <code>useCurrentClient()</code>（新版 dApp
        Kit 已移除 <code>useSuiClientQuery</code>）。详细说明见第十八章正文与第十七章钱包集成。
      </p>
      <p style={{ marginBottom: '1rem' }}>
        <ConnectButton />
      </p>
      <p>
        当前账户：{account ? account.address : '（未连接）'}
      </p>
      {chainProbe.isError ? (
        <p>链上探测失败: {String(chainProbe.error)}</p>
      ) : (
        <p>
          testnet <code>getChainIdentifier</code>:{' '}
          {chainProbe.data != null
            ? JSON.stringify(chainProbe.data)
            : chainProbe.isPending
              ? '…'
              : ''}
        </p>
      )}
      <p>
        合约示例见 <code>../move_lab/</code>，脚本见 <code>../scripts/</code>。
      </p>
    </main>
  );
}
