package aiworkergrpc

import (
	"context"
	"fmt"
	"strings"
	"time"

	"mediguide/internal/aiworkerpb"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/metadata"
)

type Client struct {
	conn   *grpc.ClientConn
	client aiworkerpb.AIWorkerServiceClient
	secret string
}

func NewClient(ctx context.Context, addr, secret string) (*Client, error) {
	addr = strings.TrimSpace(addr)
	if addr == "" {
		return nil, fmt.Errorf("AI worker gRPC address is not configured")
	}

	dialCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	conn, err := grpc.DialContext(
		dialCtx,
		addr,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		return nil, err
	}
	return &Client{
		conn:   conn,
		client: aiworkerpb.NewAIWorkerServiceClient(conn),
		secret: strings.TrimSpace(secret),
	}, nil
}

func (c *Client) Close() error {
	if c == nil || c.conn == nil {
		return nil
	}
	return c.conn.Close()
}

func (c *Client) AskRAG(ctx context.Context, req *aiworkerpb.AskRAGRequest) (*aiworkerpb.AskRAGResponse, error) {
	return c.client.AskRAG(c.callContext(ctx), req)
}

func (c *Client) RunIngestionJob(ctx context.Context, jobID string) (*aiworkerpb.RunIngestionJobResponse, error) {
	return c.client.RunIngestionJob(
		c.callContext(ctx),
		&aiworkerpb.RunIngestionJobRequest{JobId: jobID},
	)
}

func (c *Client) callContext(ctx context.Context) context.Context {
	if c.secret == "" {
		return ctx
	}
	return metadata.AppendToOutgoingContext(ctx, "x-worker-secret", c.secret)
}
